import {
  OrchestrationClient,
  buildAzureContentFilter,
  buildDocumentGroundingConfig
} from '@sap-ai-sdk/orchestration';

import {
  AzureOpenAiEmbeddingClient,
  AzureOpenAiChatClient
} from '@sap-ai-sdk/langchain';

import { VectorApi } from '@sap-ai-sdk/document-grounding';

import TextLoader from 'langchain/document_loaders/fs/text';
import RecursiveCharacterTextSplitter from 'langchain/text_splitter';
import path from 'path';

import cds from '@sap/cds';
const { DocumentSplits } = cds.entities;
const { SELECT } = cds.ql;

const chatModelName = 'gpt-4o-mini';
const embeddingModelName = 'text-embedding-ada-002-v2';

async function createVectorEmbedding() {
  try {
    const loader = new TextLoader(path.resolve('db/data/demo_grounding.txt'));
    const document = await loader.load();

    const splitter = new RecursiveCharacterTextSplitter({
      chunkSize: 500,
      chunkOverlap: 0,
      addStartIndex: true
    });

    const documentSplits = await splitter.splitDocuments(document);

    const embeddingClient = new AzureOpenAiEmbeddingClient({
      modelName: embeddingModelName,
      maxRetries: 0
    });

    const embeddings = await embeddingClient.embedDocuments(documentSplits);

    return [embeddings, documentSplits, loader.path];
  } catch (error) {
    console.log(`Error while generating embeddings.
      Error: ${JSON.stringify(error.response)}`);
    throw error;
  }
}

async function executeRAG(user_query) {
  try {
    const embeddingClient = new AzureOpenAiEmbeddingClient({
      modelName: embeddingModelName,
      maxRetries: 0
    });

    let embedding = await embeddingClient.embedQuery(user_query);

    let splits = await SELECT.from(DocumentSplits)
      .orderBy`cosine_similarity(embedding, to_real_vector(${embedding})) DESC`;

    let text_chunk = splits[0].text_chunks;

    const message = {
      role: 'user',
      content: [
        {
          type: 'text',
          text:
            ` You are an assistant for HR recruiter and manager.
            You are receiving a user query to create a job posting for new hires.
            Consider the given context when creating the job posting to include company relevant information like pay range and employee benefits.
            Consider all the input before responding.
            context: ${text_chunk}` + user_query
        }
      ],
      context: text_chunk
    };

    const chatClient = new AzureOpenAiChatClient({
      modelName: chatModelName,
      maxRetries: 0
    });

    let ragResponse = await chatClient.invoke([message]);

    return [user_query, ragResponse.content];
  } catch (error) {
    console.log(`Error while executing RAG.
      Error: ${JSON.stringify(error.response)}`);
    throw error;
  }
}

async function orchestrateJobPostingCreation(user_query) {
  const document = await createDocument();

  try {
    const filter = buildAzureContentFilter({ Hate: 2, Violence: 4 });
    const orchestrationClient = new OrchestrationClient(
      {
        llm: {
          model_name: chatModelName,
          model_params: { max_tokens: 1000, temperature: 0.1 }
        },
        templating: {
          template: [
            {
              role: 'user',
              content:
                'You are an assistant for creating Job Postings. UserQuestion: {{?user_query}} Context: {{?document}}'
            }
          ]
        },
        grounding: buildDocumentGroundingConfig({
          input_params: [user_query],
          output_param: document
        }),
        filtering: {
          input: filter,
          output: filter
        },
        masking: {
          masking_providers: [
            {
              type: 'sap_data_privacy_integration',
              method: 'pseudonymization',
              entities: [{ type: 'profile-email' }, { type: 'profile-person' }]
            }
          ]
        }
      },
      { resourceGroup: '<your-resource-group>' }
    );
    const response = await orchestrationClient.chatCompletion();
    return [user_query, response.getContent()];
  } catch (error) {
    console.log(
      `Error while generating Job Posting.
      Error: ${JSON.stringify(error.response)}`
    );
    throw error;
  }
}

async function createDocument() {
  const loader = new TextLoader(path.resolve('db/data/demo_grounding.txt'));
  const document = await loader.load();

  const response = await VectorApi.createCollection(
    {
      title: 'cap-ai-codejam-<Your-Initials>',
      embeddingConfig: {
        modelName: 'text-embedding-ada-002-v2'
      },
      metadata: []
    },
    {
      'AI-Resource-Group': 'default'
    }
  ).executeRaw();

  const collectionId = response.headers.location.split('/').at(-2);

  const documentResponse = await VectorApi.createDocuments(
    collectionId,
    {
      documents: [
        {
          metadata: [],
          chunks: [
            {
              content: `${document}`,
              metadata: []
            }
          ]
        }
      ]
    },
    {
      'AI-Resource-Group': 'default'
    }
  ).execute();

  return documentResponse.documents[0];
}

export { createVectorEmbedding, executeRAG, orchestrateJobPostingCreation };
