"""CLI contracts tested against a local HTTP fixture and real child processes."""

import contextlib
import http.server
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "bin/llm"
loader = importlib.machinery.SourceFileLoader("model_cli", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
llm = importlib.util.module_from_spec(spec)
loader.exec_module(llm)


class API(http.server.BaseHTTPRequestHandler):
    requests = []
    incomplete = False
    failure = False
    redirect = None

    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path == "/redirect-target":
            API.requests.append((self.path, None, self.headers.get("Authorization")))
        if self.redirect_response():
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"data": [{"id": "served-model"}]}')

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        API.requests.append((self.path, body, self.headers.get("Authorization")))
        if self.redirect_response():
            return
        if API.failure:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'private prompt and key should not be printed')
            return
        self.send_response(200)
        self.end_headers()
        if body.get("stream"):
            self.wfile.write(b': keepalive\n\ndata: {"choices":[{"delta":{"role":"assistant"}}]}\n\n')
            if API.incomplete:
                return
            self.wfile.write(b'data: {"choices":[{"delta":{"reasoning_content":"thinking"}}]}\n\n')
            self.wfile.write(b'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n')
            self.wfile.write(b'data: {"choices":[],"usage":{"completion_tokens":5,"prompt_tokens":3}}\n\n')
            self.wfile.write(b'data: [DONE]\n\n')
        elif self.path.endswith("embeddings"):
            self.wfile.write(b'{"data":[{"embedding":[0.1,0.2]}]}')
        else:
            self.wfile.write(b'{"choices":[{"message":{"content":"ok","tool_calls":[{"id":"call1","type":"function","function":{"name":"lookup","arguments":"{}"}}]}}]}')

    def redirect_response(self):
        if API.redirect and self.path != "/redirect-target":
            code, target = API.redirect
            self.send_response(code)
            self.send_header("Location", target)
            self.end_headers()
            return True
        return False


class ModelCLI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.api = http.server.ThreadingHTTPServer(("127.0.0.1", 0), API)
        cls.thread = threading.Thread(target=cls.api.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.api.shutdown()
        cls.api.server_close()
        cls.thread.join()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.env = patch.dict(os.environ, {"LLM_CONFIG": str(self.root / "config.json"),
                                          "XDG_RUNTIME_DIR": str(self.root), "TEST_LLM_KEY": "fixture-key"})
        self.env.start()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(self.env.stop)
        API.requests.clear()
        API.incomplete = API.failure = False
        API.redirect = None
        self.call("endpoint", "test", f"http://127.0.0.1:{self.api.server_port}/v1", "--key-env", "TEST_LLM_KEY")
        self.call("add", "demo", "served-model", "--runtime", "test", "--format", "endpoint")

    def call(self, *arguments, code=0):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            result = llm.main(list(arguments))
        self.assertEqual(result, code, err.getvalue())
        return out.getvalue(), err.getvalue()

    def test_request_preserves_tool_history_and_structured_options(self):
        request = self.root / "request.json"
        original = {"messages": [{"role": "tool", "tool_call_id": "call0", "content": "42"}],
                    "tools": [{"type": "function", "function": {"name": "lookup"}}],
                    "model": "wrong", "stream": True}
        request.write_text(json.dumps(original))
        out, _ = self.call("chat", "demo", "--request", str(request), "--json")
        path, body, auth = API.requests[-1]
        self.assertEqual(path, "/v1/chat/completions")
        self.assertEqual(body["model"], "served-model")
        self.assertEqual(body["messages"], original["messages"])
        self.assertEqual(body["tools"], original["tools"])
        self.assertFalse(body["stream"])
        self.assertEqual(body["response_format"], {"type": "json_object"})
        self.assertEqual(auth, "Bearer fixture-key")
        self.assertEqual(json.loads(out)["tool_calls"][0]["id"], "call1")

    def test_schema_and_file_input(self):
        schema = self.root / "schema.json"
        schema.write_text('{"type":"object","properties":{}}')
        text = self.root / "input.txt"
        text.write_text("document")
        self.call("chat", "demo", "summarize", "--system", "be precise", "--input", str(text), "--schema", str(schema))
        body = API.requests[-1][1]
        self.assertEqual(body["messages"][0]["role"], "system")
        self.assertIn("document", body["messages"][1]["content"])
        self.assertEqual(body["response_format"]["type"], "json_schema")

    def test_embedding_route(self):
        out, _ = self.call("embed", "demo", "text")
        self.assertEqual(API.requests[-1][0], "/v1/embeddings")
        self.assertEqual(json.loads(out)["data"][0]["embedding"], [0.1, 0.2])

    def test_sse_usage_and_benchmark_no_prompt_logging(self):
        report = self.root / "bench.json"
        out, _ = self.call("bench", "demo", "private prompt", "--warmup", "0", "--runs", "2", "--output", str(report))
        result = json.loads(out)
        self.assertEqual(len(result["runs"]), 2)
        self.assertGreater(result["runs"][0]["ttft_seconds"], 0)
        self.assertEqual(result["runs"][0]["usage"]["completion_tokens"], 5)
        self.assertNotIn("private prompt", report.read_text())

    def test_incomplete_stream_fails(self):
        API.incomplete = True
        _, err = self.call("bench", "demo", "test", "--warmup", "0", "--runs", "1", code=1)
        self.assertIn("Incomplete SSE", err)

    def test_http_error_does_not_print_response_body(self):
        API.failure = True
        _, err = self.call("chat", "demo", "test", code=1)
        self.assertIn("HTTP 400", err)
        self.assertNotIn("private prompt", err)
        self.assertNotIn("fixture-key", err)

    def test_registry_scan_idempotent_and_invalid_endpoint_atomic(self):
        (self.root / "a.gguf").write_text("GGUF")
        self.call("scan", str(self.root), "--register")
        self.call("scan", str(self.root), "--register")
        self.assertEqual(len(llm.load_config()["models"]), 2)
        self.call("init")
        self.assertIn("demo", llm.load_config()["models"])
        self.call("endpoint", "bad", "http://secret:password@host/v1", code=1)
        self.assertNotIn("bad", llm.load_config()["runtimes"])

    def test_authenticated_api_refuses_all_redirects(self):
        runtime = llm.runtime_config(llm.load_config(), "test")
        for host in ("127.0.0.1", "localhost"):
            for code in (301, 302, 303, 307, 308):
                for body in (None, {"prompt": "private prompt"}):
                    with self.subTest(host=host, code=code, body=body):
                        API.requests.clear()
                        API.redirect = (code, f"http://{host}:{self.api.server_port}/redirect-target")
                        with self.assertRaisesRegex(ValueError, f"API HTTP {code}") as error:
                            llm.request_json(runtime, "/models", body)
                        self.assertFalse(any(path == "/redirect-target" for path, _, _ in API.requests))
                        self.assertNotIn("fixture-key", str(error.exception))
                        self.assertNotIn("private prompt", str(error.exception))

    def test_scan_registers_only_first_split_shard(self):
        for index in (1, 2, 3, 10):
            (self.root / f"model-{index:05d}-of-00010.gguf").write_text("GGUF")
        (self.root / "single.gguf").write_text("GGUF")
        self.call("scan", str(self.root), "--register")
        self.call("scan", str(self.root), "--register")
        sources = {model["source"] for model in llm.load_config()["models"].values()}
        self.assertEqual(sources, {"served-model", str(self.root / "model-00001-of-00010.gguf"), str(self.root / "single.gguf")})

    def test_gpu_preflight_counts_all_shards(self):
        source = self.root / "model-00001-of-00003.gguf"
        for index in range(1, 4):
            with source.with_name(f"model-{index:05d}-of-00003.gguf").open("wb") as shard:
                shard.truncate(1024**3)
        model = {"source": str(source), "format": "gguf"}
        with patch.object(llm, "request_json", return_value={"models": []}), patch.object(llm.shutil, "which", return_value="nvidia-smi"), patch.object(llm.subprocess, "check_output", return_value="4096\n"):
            with self.assertRaisesRegex(ValueError, "exceed free VRAM"):
                llm.gpu_preflight(model, llm.load_config())
        source.with_name("model-00003-of-00003.gguf").unlink()
        with self.assertRaisesRegex(ValueError, "Incomplete split GGUF"):
            llm.gguf_shards(source)
        with self.assertRaisesRegex(ValueError, "first GGUF shard"):
            llm.gguf_shards(source.with_name("model-00002-of-00003.gguf"))

    def test_formats_and_literal_arguments(self):
        model = self.root / "model; touch BAD.gguf"
        model.write_text("GGUF")
        self.call("add", "local", str(model))
        out, _ = self.call("serve", "local", "--dry-run")
        self.assertIn("--n-gpu-layers 0", out)
        self.assertIn("--port 18080", out)
        self.call("add", "bad", str(model), "--runtime", "vllm", code=1)
        self.assertFalse((self.root / "BAD.gguf").exists())

    def test_gpu_lock_excludes_second_runtime(self):
        with llm.gpu_lock():
            with self.assertRaisesRegex(ValueError, "owns GPU lock"):
                with llm.gpu_lock():
                    self.fail("Second owner entered")
        with llm.gpu_lock():
            pass

    def test_loaded_ollama_blocks_gpu(self):
        with patch.object(llm, "request_json", return_value={"models": [{"name": "busy"}]}):
            with self.assertRaisesRegex(ValueError, "Ollama has loaded"):
                llm.gpu_preflight({}, llm.load_config())

    def test_native_runtime_commands_and_tabby_model_id(self):
        for engine, port in (("vllm", 18081), ("sglang", 18082)):
            self.call("add", engine, "owner/model", "--runtime", engine, "--format", "hf")
            out, _ = self.call("serve", engine, "--gpu", "--dry-run", "--context", "2048")
            self.assertIn(f"--port {port}", out)
            self.assertIn("--served-model-name " + engine, out)
            self.assertIn("0.75", out)
            self.call("serve", engine, "--dry-run", code=1)
        directory = self.root / "native-exl3"
        directory.mkdir()
        self.call("add", "tabby-model", str(directory), "--runtime", "tabby", "--format", "exl3")
        self.call("runtime", "tabby", "--command", json.dumps([sys.executable, "/path/main.py"]), "--cwd", str(directory))
        out, _ = self.call("serve", "tabby-model", "--gpu", "--dry-run")
        self.assertIn("--model-name native-exl3", out)
        self.assertEqual(llm.load_config()["models"]["tabby-model"]["model"], "native-exl3")

    def test_cpu_build_cannot_claim_gpu_offload(self):
        model = self.root / "test.gguf"
        model.write_text("GGUF")
        self.call("add", "local", str(model))
        self.call("runtime", "llama", "--command", json.dumps([sys.executable]))
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        self.call("endpoint", "llama", f"http://127.0.0.1:{port}/v1")
        with patch.object(llm.subprocess, "check_output", return_value="Available devices: BLAS"):
            _, err = self.call("serve", "local", "--gpu", code=1)
        self.assertIn("no CUDA device", err)

    def test_model_request_defaults_and_override(self):
        self.call("add", "demo", "served-model", "--runtime", "test", "--format", "endpoint",
                  "--request-defaults", '{"chat_template_kwargs":{"enable_thinking":false},"temperature":0.5}')
        self.call("chat", "demo", "hi")
        self.assertFalse(API.requests[-1][1]["chat_template_kwargs"]["enable_thinking"])
        request = self.root / "override.json"
        request.write_text('{"messages":[{"role":"user","content":"hi"}],"temperature":0.1}')
        self.call("chat", "demo", "--request", str(request))
        self.assertEqual(API.requests[-1][1]["temperature"], 0.1)
        self.call("chat", "demo", "--request", str(request), "--temperature", "0.25", "--max-tokens", "64")
        self.assertEqual(API.requests[-1][1]["temperature"], 0.25)
        self.assertEqual(API.requests[-1][1]["max_tokens"], 64)

    def test_backup_flags_forward_to_helper(self):
        with patch.object(llm.subprocess, "call", return_value=0) as execute:
            self.call("backup", "--dry-run", "--verify")
        self.assertEqual(execute.call_args.args[0][-2:], ["--dry-run", "--verify"])

    def test_pull_uses_writable_user_store_when_system_store_missing(self):
        with patch.dict(os.environ, {"XDG_DATA_HOME": str(self.root), "LLM_CONFIG": str(self.root / "config.json")}, clear=True):
            with patch.object(llm.os, "access", return_value=False), patch.object(llm.subprocess, "call", return_value=0) as execute:
                self.call("pull", "owner/repo", "model.gguf", "commit")
        self.assertEqual(execute.call_args.kwargs["env"]["LLM_MODELS_DIR"], str(self.root / "llama-models"))

    def test_wrong_loaded_llama_model_is_rejected(self):
        model = self.root / "test.gguf"
        model.write_text("GGUF")
        self.call("add", "local", str(model))
        with patch.object(llm, "request_json", return_value={"data": [{"id": "other-model"}]}):
            _, err = self.call("chat", "local", "hi", code=1)
        self.assertIn("not exposed", err)

    def test_relative_hf_directory_stays_valid_after_chdir(self):
        original = Path.cwd()
        (self.root / "weights").mkdir()
        try:
            os.chdir(self.root)
            self.call("add", "native", "./weights", "--runtime", "vllm", "--format", "hf")
        finally:
            os.chdir(original)
        self.assertEqual(llm.load_config()["models"]["native"]["source"], str(self.root / "weights"))

    def test_foreground_shutdown_reaps_child_and_releases_lock(self):
        model = self.root / "test.gguf"
        model.write_text("GGUF")
        child_script = self.root / "server.py"
        pid_file = self.root / "child.pid"
        child_script.write_text("import os,time\nfrom pathlib import Path\nPath(" + repr(str(pid_file)) + ").write_text(str(os.getpid()))\ntime.sleep(30)\n")
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        self.call("endpoint", "llama", f"http://127.0.0.1:{port}/v1")
        self.call("add", "local", str(model))
        with llm.edit_config() as config:
            config["runtimes"]["llama"]["command"] = [sys.executable, str(child_script)]
        process = subprocess.Popen([sys.executable, str(SCRIPT), "serve", "local"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while not pid_file.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(pid_file.exists())
            pid = int(pid_file.read_text())
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=5)
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)
            with llm.gpu_lock():
                pass
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()


if __name__ == "__main__":
    unittest.main()
