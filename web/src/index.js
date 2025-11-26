import * as monaco from 'monaco-editor/esm/vs/editor/editor.api.js';
import 'monaco-editor/esm/vs/basic-languages/javascript/javascript.contribution.js'
import 'monaco-editor/esm/vs/basic-languages/typescript/typescript.contribution.js'
import * as typescript from 'monaco-editor/esm/vs/language/typescript/monaco.contribution.js';
import './styles.css';

import makeEditorWorker from 'monaco-editor/esm/vs/editor/editor.worker.js';
import makeTSWorker from 'monaco-editor/esm/vs/language/typescript/ts.worker.js';

const TOP_LEVEL_EXPORTABLE_KINDS = new Set([
    'class',
    'function',
    'const',
    'let',
    'var',
]);

const defaultTypescriptCompilerOptions = { ...typescript.typescriptDefaults.getCompilerOptions() };
const defaultJavascriptCompilerOptions = { ...typescript.javascriptDefaults.getCompilerOptions() };

class MonacoEditorHost {
    constructor() {
        this.contextKeys = {};
    }

    create(options) {
        this.editor = monaco.editor.create(document.getElementById('editor'), options);
        this.editor.focus();
        this.editor.onDidChangeModelContent((event) => {
            const text = this.editor.getValue();
            window.webkit?.messageHandlers?.updateText.postMessage(btoa(text));
        });
    }

    withMonaco(fn) {
        fn(monaco, this.editor);
    }

    withTypescript(fn) {
        fn(typescript);
    }

    createContextKey(key, defaultValue) {
        const contextKey = this.editor.createContextKey(key, defaultValue);
        this.contextKeys[key] = contextKey;
    }

    focus() {
        this.editor.focus();
    }

    getContextKey(key) {
        return this.contextKeys[key].get();
    }

    resetContextKey(key) {
        this.contextKeys[key].reset();
    }

    setContextKey(key, value) {
        this.contextKeys[key].set(value);
    }

    setText(text) {
        this.editor.setValue(text);
    }

    updateOptions(options) {
        this.editor.updateOptions(options);
    }

    updateDefaultTypescriptCompilerOptions(options) {
        typescript.typescriptDefaults.setCompilerOptions({ ...defaultTypescriptCompilerOptions, ...options });
    }

    updateDefaultJavascriptCompilerOptions(options) {
        typescript.javascriptDefaults.setCompilerOptions({ ...defaultJavascriptCompilerOptions, ...options });
    }

    requestTopLevelSymbols() {
        this.doRequestTopLevelSymbols();
    }

    async doRequestTopLevelSymbols() {
        const model = this.editor.getModel();
        const uri = model.uri;
        const fileName = uri.toString();

        const getWorker = (model.getLanguageId() === 'typescript')
                ? typescript.getTypeScriptWorker
                : typescript.getJavaScriptWorker;
        const workerAccessor = await getWorker();
        const client = await workerAccessor(uri);

        const tree = await client.getNavigationTree(fileName);

        const symbols = [];
        for (const { kind, text } of tree.childItems) {
            if (TOP_LEVEL_EXPORTABLE_KINDS.has(kind)) {
                symbols.push({ kind, text });
            }
        }

        window.webkit.messageHandlers.topLevelSymbols.postMessage(symbols);
    }
}

window.MonacoEnvironment = {
    getWorker(_moduleId, label) {
        switch (label) {
            case 'typescript':
            case 'javascript':
                return makeTSWorker();
            default:
                return makeEditorWorker();
        }
    }
};

window.editor = new MonacoEditorHost();
