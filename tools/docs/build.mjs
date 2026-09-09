import { marked } from 'marked';
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const docsDir = join(root, 'docs');
const outDir = join(docsDir, 'out');
mkdirSync(outDir, { recursive: true });

const files = readdirSync(docsDir)
  .filter((f) => f.endsWith('.md'))
  .sort();

let body = '';
for (const f of files) {
  const md = readFileSync(join(docsDir, f), 'utf8');
  body += `<section>\n${marked.parse(md)}\n</section>\n`;
}

const title = 'ERP Repostería + Gestión Ágil — Documentación';
const html = `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>${title}</title>
<style>
:root { color-scheme: light; }
* { box-sizing: border-box; }
body {
  font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  max-width: 900px; margin: 0 auto; padding: 40px 24px;
  color: #1a1a1a; line-height: 1.55;
}
h1, h2, h3 { color: #b45309; line-height: 1.2; }
h1 { font-size: 1.8em; border-bottom: 2px solid #b45309; padding-bottom: .2em; }
h2 { font-size: 1.35em; margin-top: 1.6em; border-bottom: 1px solid #ddd; padding-bottom: .15em; }
h3 { font-size: 1.1em; margin-top: 1.2em; }
section { page-break-before: always; }
section:first-of-type { page-break-before: auto; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; font-size: .92em; }
th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
th { background: #fef3c7; }
code { background: #f4f4f5; padding: 2px 5px; border-radius: 4px; font-size: .9em; }
pre { background: #f4f4f5; padding: 12px; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; }
a { color: #b45309; }
blockquote { border-left: 4px solid #b45309; margin: 1em 0; padding: .2em 1em; background: #fffbeb; }
</style>
</head>
<body>
<header>
<h1>${title}</h1>
<p>Generado desde <code>docs/*.md</code> el ${new Date().toISOString().slice(0, 10)}.</p>
</header>
${body}
</body>
</html>
`;

const htmlPath = join(outDir, 'plan.html');
const pdfPath = join(outDir, 'plan.pdf');
writeFileSync(htmlPath, html);
console.log(`HTML -> ${htmlPath}`);

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/chromium',
  args: ['--no-sandbox'],
});
const page = await browser.newPage();
await page.goto(`file://${htmlPath}`, { waitUntil: 'networkidle0' });
await page.pdf({ path: pdfPath, format: 'A4', printBackground: true });
await browser.close();
console.log(`PDF  -> ${pdfPath}`);