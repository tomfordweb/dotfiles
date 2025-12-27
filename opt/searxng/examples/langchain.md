# Example using langchain tools to query searxng

One important thing to note is that `json` format must be enabled.

To get the "engine" name, go to [searxng settings](https://searx.docker.localhost/preferences)

```typescript
#!/usr/bin/env tsx

import { SearxngSearch } from "@langchain/community/tools/searxng_search";
import { ollamaModelFactory } from "./llm/ollama.js";
import { createAgent } from "langchain";

const model = ollamaModelFactory("qwen3:14b");

const tools = [
  new SearxngSearch({
    apiBase: "https://searx.docker.localhost",
    params: {
      format: "json", // Do not change this, format other than "json" is will throw error
      engines: "wp", // wikipedia
    },
    headers: {},
  }),
];

const agent = createAgent({
  model,
  tools,
});

const result = await agent.invoke({
  messages: [
    [
      "ai",
      "Answer the following questions as best you can. In your final answer, use a bulleted list markdown format.",
    ],
    ["human", "Help me write an 500 word essay on Frederick Meijer."],
  ],
});
result.messages.forEach((msg) => {
  console.log(msg.content);
});
```

The loop will output the following:

```
Answer the following questions as best you can. In your final answer, use a bulleted list markdown format.
```

```
Help me write an 500 word essay on Frederick Meijer.
```

```json
{"title":"Frederik GH Meijer [1919-2011] - New Netherland Institute","link":"https://www.newnetherlandinstitute.org/history-and-heritage/dutch_americans/frederik-g-h-meijer","snippet":"Through this gift, Frederick Meijer becomes a major contributor to the field of Netherlandic studies. Frederik Meijer lived a long life. He was born in 1919, ..."},{"title":"Frederik Meijer - Wikipedia","link":"https://en.wikipedia.org/wiki/Frederik_Meijer","snippet":"Frederik Gerhard Hendrik \"Fred\" Meijer (December 7, 1919 – November 25, 2011) was an American billionaire businessman who was the chairman of the Meijer ..."},{"title":"How Fred Meijer's legacy shaped West Michigan (editorial)","link":"https://www.mlive.com/opinion/grand-rapids/2011/11/how_fred_meijers_legacy_shaped.html","snippet":"Nov 29, 2011 ... The Fred Meijer legacy can be seen across the Midwest. His imprint is in the many stores he created and in the retail model he pioneered."},{"title":"Frederik Meijer: 1919-2011 | Progressive Grocer","link":"https://progressivegrocer.com/frederik-meijer-1919-2011","snippet":"Nov 27, 2011 ... In his adopted hometown of Grand Rapids, Meijer played a vital role in the early years of the local Urban League and Goodwill Industries, and ..."},{"title":"Businessman and philanthropist Frederik G. H. Meijer remembered ...","link":"https://www.gvsu.edu/gvnext/2011/businessman-and-philanthropist-frederik-g-h-meijer-remembered-5988.htm","snippet":"Nov 26, 2011 ... Throughout his life he made many contributions that helped local medical institutions, educational facilities, and nature preserves. He was ..."},{"title":"Fred Meijer Remembered","link":"https://fmgsf.org/articles/fred-meijer-remembered","snippet":"Jan 30, 2012 ... Less well known, but equally important, by giving generously to what would become the Frederik Meijer Gardens & Sculpture Foundation, he helped ..."},{"title":"Frederik GH Meijer: Net Worth & Biography - Goodreturns","link":"https://www.goodreturns.in/frederik-g-h-meijer-net-worth-and-biography-blnr4414.html","snippet":"His legacy extends beyond business; he contributed significantly to cultural and educational institutions in Michigan, including the Frederik Meijer Gardens and ..."},{"title":"Meijer remembered as a “great boss” and an “inspirational leader”","link":"https://www.michiganpublic.org/arts-culture/2011-11-29/meijer-remembered-as-a-great-boss-and-an-inspirational-leader","snippet":"Nov 29, 2011 ... Frederik Meijer, the Chairman Emeritus of Meijer grocery stores has died at the age of 91.Meijer Corp. owns more than 150 stores in Michigan and ..."},{"title":"Frederik Gerhard Meijer was born in 1919 in Greenville, Michigan. In","link":"https://www.facebook.com/groups/michianahistory/posts/2275282495990408/","snippet":"Apr 13, 2023 ... Frederik Gerhard Meijer was born in 1919 in Greenville, Michigan. In the midst of the Great Depression, Fred's father decided to help his ..."},{"title":"Frederik Meijer - Michigan 4-H Foundation","link":"https://mi4hfdtn.org/ecs/meijer-fred/","snippet":"A founding donor of the Frederik Meijer Gardens and Sculpture Park, Meijer is also a patron of the Greenville Area Foundation, the Lakeview Foundation and ..."}
```

- **Introduction**: Frederick Gerhard Hendrik "Fred" Meijer (1919–2011) was an American billionaire businessman, philanthropist, and chairman of the Meijer supermarket chain. Born in Greenville, Michigan, during the Great Depression, Meijer’s life story reflects resilience, innovation, and a profound commitment to community development. His legacy spans retail, education, healthcare, and the arts, leaving an indelible mark on West Michigan and beyond.

- **Early Life and Business Career**: Meijer was born into a Dutch-American family in Greenville, Michigan, during a time of economic hardship. His father, a grocer, instilled in him a strong work ethic and a belief in the power of community. In 1936, at the age of 17, Meijer joined his father’s store, which later became the foundation of the Meijer supermarket chain. He expanded the business into a regional powerhouse, pioneering a retail model that combined low prices with high-quality products. By the time of his death, Meijer Corp. operated over 150 stores across Michigan and Ohio, becoming a cornerstone of the Midwest economy.

- **Philanthropy and Community Impact**: Beyond his business success, Meijer was a dedicated philanthropist. He supported numerous organizations, including the Urban League, Goodwill Industries, and the Lakeview Foundation, focusing on education, employment, and social equity. His contributions to healthcare and education were particularly significant, with donations to hospitals, universities, and research institutions. Perhaps most notably, he founded the **Frederik Meijer Gardens & Sculpture Park** in Grand Rapids, Michigan, a cultural landmark that combines art, nature, and public access. This institution, along with the **Frederik Meijer Park**, reflects his vision of creating spaces that inspire and educate.

- **Legacy and Influence**: Meijer’s leadership extended beyond his corporate role. Colleagues and employees often described him as a "great boss" and "inspirational leader," emphasizing his hands-on approach and dedication to fostering a positive work environment. His business model, which emphasized customer service and community engagement, set a standard for retail in the United States. Even after retiring in 1996, he remained actively involved in philanthropy, ensuring his influence endured through the Frederik Meijer Gardens & Sculpture Foundation and other initiatives. His contributions to Netherlandic studies, through gifts to academic institutions, further highlight his commitment to preserving cultural heritage.

- **Conclusion**: Frederick Meijer’s life exemplifies the intersection of entrepreneurial success and civic responsibility. From building a retail empire to transforming communities through philanthropy, his impact continues to shape West Michigan and beyond. His legacy lives on in the institutions he founded, the lives he touched, and the enduring values of generosity and innovation he championed. As a businessman, leader, and humanitarian, Meijer remains a revered figure in American history.
