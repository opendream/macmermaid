// Development only. The packaged app uses the checked-in bundle without Node/npm.
import {build} from 'esbuild';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const here = path.dirname(fileURLToPath(import.meta.url));
await build({
  absWorkingDir: here,
  entryPoints: ['node_modules/yaml/browser/index.js'],
  bundle: true, format: 'iife', globalName: 'YAML', minify: true, target: 'safari17.4',
  outfile: '../../Sources/MacMermaid/Resources/Web/yaml.min.js'
});
