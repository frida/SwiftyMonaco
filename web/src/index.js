import * as monaco from 'monaco-editor/esm/vs/editor/editor.api';
import 'monaco-editor/esm/vs/basic-languages/javascript/javascript.contribution'
import 'monaco-editor/esm/vs/basic-languages/typescript/typescript.contribution'
import * as typescript from 'monaco-editor/esm/vs/language/typescript/monaco.contribution';
import './styles.css';

import makeEditorWorker from 'monaco-editor/esm/vs/editor/editor.worker';
import makeTSWorker from 'monaco-editor/esm/vs/language/typescript/ts.worker';

class MonacoEditorHost {
    constructor() {
        this.contextKeys = {};
    }

    create(options) {
        const hostElement = document.createElement('div');
        hostElement.id = 'editor';
        document.body.appendChild(hostElement);

        this.editor = monaco.editor.create(hostElement, options);
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
        typescript.typescriptDefaults.setCompilerOptions({ ...options, allowNonTsExtensions: true });
    }
}

function main() {
    window.editor = new MonacoEditorHost();
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

document.addEventListener('DOMContentLoaded', main);
