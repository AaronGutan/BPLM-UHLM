import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Pinecone } from '@pinecone-database/pinecone';

const INDEX_NAME = 'bplm-consolidation-code';
const NAMESPACE = 'cfe-consolidation';
const QUERY =
	'как зарегистрировать объекты на узле плана обмена через HTTP после сверки GUID';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const records = JSON.parse(
	readFileSync(join(scriptDir, 'consolidation-records.json'), 'utf8'),
);

async function ensureIndex(pc) {
	const existing = await pc.listIndexes();
	const found = existing.indexes?.find((item) => item.name === INDEX_NAME);

	if (found) {
		return pc.index(INDEX_NAME);
	}

	await pc.createIndexForModel({
		name: INDEX_NAME,
		cloud: 'aws',
		region: 'us-east-1',
		embed: {
			model: 'multilingual-e5-large',
			fieldMap: { text: 'chunk_text' },
		},
		waitUntilReady: true,
	});

	return pc.index(INDEX_NAME);
}

async function main() {
	if (!process.env.PINECONE_API_KEY) {
		console.error(
			'PINECONE_API_KEY не задан. Добавьте ключ в .env в корне репозитория и перезапустите сессию Cursor.',
		);
		process.exit(1);
	}

	const pc = new Pinecone();
	const index = await ensureIndex(pc);
	const namespace = index.namespace(NAMESPACE);

	console.log(`Индекс: ${INDEX_NAME}, namespace: ${NAMESPACE}`);
	console.log(`Загрузка ${records.length} фрагментов кода расширения консолидации...`);

	await namespace.upsertRecords({ records });
	await new Promise((resolve) => setTimeout(resolve, 5000));

	console.log(`\nЗапрос: "${QUERY}"\n`);

	const response = await namespace.searchRecords({
		query: {
			topK: 3,
			inputs: { text: QUERY },
			filter: { subsystem: { $eq: 'consolidation' } },
		},
		fields: ['chunk_text', 'module', 'topic'],
		rerank: {
			model: 'bge-reranker-v2-m3',
			topN: 3,
			rankFields: ['chunk_text'],
		},
	});

	for (const [position, hit] of response.result.hits.entries()) {
		const fields = hit.fields ?? {};
		console.log(
			`${position + 1}. score=${hit.score?.toFixed(4)} | ${fields.module} | ${fields.topic}`,
		);
		console.log(`   ${fields.chunk_text}\n`);
	}
}

main().catch((error) => {
	console.error(error.message ?? error);
	process.exit(1);
});
