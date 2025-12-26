import * as monaco from 'monaco-editor/esm/vs/editor/editor.api.js';
import 'monaco-editor/esm/vs/basic-languages/javascript/javascript.contribution.js';
import 'monaco-editor/esm/vs/basic-languages/typescript/typescript.contribution.js';
import * as typescript from 'monaco-editor/esm/vs/language/typescript/monaco.contribution.js';
import './styles.css';

import makeEditorWorker from 'monaco-editor/esm/vs/editor/editor.worker.js';
import makeTSWorker from './typescript.worker.js';

const TOP_LEVEL_EXPORTABLE_KINDS = new Set([
    'class',
    'function',
    'const',
    'let',
    'var',
]);

const WORKSPACE_ROOT_URI = 'file:///workspace/';
const BOOTSTRAP_URI = 'file:///workspace/__bootstrap.ts';

const defaultTypescriptCompilerOptions = { ...typescript.typescriptDefaults.getCompilerOptions() };
const defaultJavascriptCompilerOptions = { ...typescript.javascriptDefaults.getCompilerOptions() };

const LANGUAGE_IDS = ['typescript', 'javascript'];

const workerStateByLanguageId = createWorkerStateByLanguageId();

class MonacoEditorHost {
    constructor() {
        this.documentPath = null;
        this.derivedDocumentPath = null;

        this.languageId = 'plaintext';

        this.model = null;
        this.pendingText = null;

        this.editor = null;

        this.contextKeys = {};

        this.fsSnapshot = null;
        this.fsSnapshotStateByLanguageId = createFSSnapshotStateByLanguageId();
    }

    clearText() {
        const model = this.model;
        if (model !== null) {
            model.setValue('');
        } else {
            this.pendingText = '';
        }
    }

    setText(text) {
        if (this.model === null) {
            this.pendingText = text;
            return;
        }

        this.model.setValue(text);
    }

    getEffectiveDocumentPath() {
        if (this.documentPath !== null) {
            return this.documentPath;
        }

        if (this.derivedDocumentPath === null) {
            this.derivedDocumentPath = defaultDocumentPathForLanguageId(this.languageId);
        }

        return this.derivedDocumentPath;
    }

    setDocumentPath(pathOrNull) {
        this.documentPath = pathOrNull;
        this.derivedDocumentPath = null;

        if (this.editor !== null) {
            this.ensureModel();
        }
    }

    setLanguageId(languageId) {
        this.languageId = languageId;

        if (this.editor !== null) {
            this.ensureModel();
        }
    }

    ensureModel() {
        const effectivePath = this.getEffectiveDocumentPath();
        const uriString = `${WORKSPACE_ROOT_URI}${effectivePath}`;
        const uri = monaco.Uri.parse(uriString);

        const existing = this.model;
        const existingUriString = (existing !== null) ? existing.uri.toString() : null;

        if (existing !== null && existingUriString === uriString && existing.getLanguageId() === this.languageId) {
            return;
        }

        const value = (existing !== null) ? existing.getValue() : (this.pendingText ?? '');
        const model = monaco.editor.createModel(value, this.languageId, uri);

        this.pendingText = null;

        if (existing !== null) {
            existing.dispose();
        }

        this.model = model;

        if (this.editor !== null) {
            this.editor.setModel(model);
        }
    }

    create(options) {
        this.ensureModel();

        const baseOptions = {
            automaticLayout: true,
        };

        this.editor = monaco.editor.create(
            document.getElementById('editor'),
            { ...baseOptions, ...options, model: this.model },
        );

        this.editor.focus();

        this.editor.onDidChangeModelContent(() => {
            const m = this.model;
            const text = m !== null ? m.getValue() : '';
            window.webkit?.messageHandlers?.updateText?.postMessage(btoa(text));
        });
    }

    updateOptions(options) {
        this.editor.updateOptions(options);
    }

    updateDefaultTypescriptCompilerOptions(options) {
        typescript.typescriptDefaults.setCompilerOptions({ ...defaultTypescriptCompilerOptions, ...options });
    }

    updateDefaultTypescriptExtraLibs(libs) {
        typescript.typescriptDefaults.setExtraLibs(libs);
    }

    updateDefaultJavascriptCompilerOptions(options) {
        typescript.javascriptDefaults.setCompilerOptions({ ...defaultJavascriptCompilerOptions, ...options });
    }

    updateDefaultJavascriptExtraLibs(libs) {
        typescript.javascriptDefaults.setExtraLibs(libs);
    }

    setFSSnapshot(snapshot) {
        this.fsSnapshot = snapshot;

        for (const languageId of LANGUAGE_IDS) {
            const workerState = workerStateByLanguageId[languageId];
            if (workerState.requested) {
                this.applyFSSnapshotIfNeeded(languageId);
            }
        }
    }

    noteWorkerRequested(languageId, generation) {
        const snapshotState = this.fsSnapshotStateByLanguageId[languageId];
        snapshotState.workerGeneration = generation;

        if (this.fsSnapshot !== null) {
            this.applyFSSnapshotIfNeeded(languageId);
        }
    }

    applyFSSnapshotIfNeeded(languageId) {
        if (this.fsSnapshot === null) {
            return;
        }

        const currentVersion = this.fsSnapshot.version;
        const snapshotState = this.fsSnapshotStateByLanguageId[languageId];

        const needsApply = (snapshotState.appliedVersion !== currentVersion)
            || (snapshotState.appliedWorkerGeneration !== snapshotState.workerGeneration);

        if (!needsApply) {
            return;
        }

        if (snapshotState.inFlight !== null) {
            return;
        }

        snapshotState.inFlight = (async () => {
            const uri = (this.model !== null) ? this.model.uri.toString() : BOOTSTRAP_URI;

            await applySnapshotForLanguage(languageId, uri, this.fsSnapshot);

            snapshotState.appliedVersion = currentVersion;
            snapshotState.appliedWorkerGeneration = snapshotState.workerGeneration;

            this.pokeValidation();
        })().finally(() => {
            snapshotState.inFlight = null;
        });
    }

    pokeValidation() {
        const { editor, model } = this;

        if (editor === null) {
            return;
        }

        if (model.getValueLength() === 0) {
            return;
        }

        const start = model.getPositionAt(0);
        const end = model.getPositionAt(1);

        const range = new monaco.Range(
            start.lineNumber,
            start.column,
            end.lineNumber,
            end.column,
        );

        const original = model.getValueInRange(range);

        const edits = [{
            range,
            text: original,
            forceMoveMarkers: false,
        }];

        const selections = this.editor.getSelections();

        if (selections === null) {
            this.editor.executeEdits('fsSnapshot', edits);
            return;
        }

        this.editor.executeEdits('fsSnapshot', edits, selections);
    }

    focus() {
        this.editor.focus();
    }

    createContextKey(key, defaultValue) {
        const contextKey = this.editor.createContextKey(key, defaultValue);
        this.contextKeys[key] = contextKey;
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

    requestTopLevelSymbols() {
        this.doRequestTopLevelSymbols();
    }

    withMonaco(fn) {
        fn(monaco, this.editor);
    }

    async doRequestTopLevelSymbols() {
        const model = this.editor.getModel();
        const uri = model.uri;
        const fileName = uri.toString();

        const languageId = model.getLanguageId();
        const getWorker = (languageId === 'typescript')
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
        const languageId = languageIdForWorkerLabel(label);
        if (languageId !== null) {
            const state = workerStateByLanguageId[languageId];

            state.generation += 1;
            state.requested = true;

            if (state.resolveRequested !== null) {
                state.resolveRequested();
                state.resolveRequested = null;
            }

            window.editor?.noteWorkerRequested(languageId, state.generation);

            return makeTSWorker();
        }

        return makeEditorWorker();
    }
};

window.editor = new MonacoEditorHost();

function createWorkerStateByLanguageId() {
    const state = {};

    for (const languageId of LANGUAGE_IDS) {
        let resolveRequested = null;

        const requestedPromise = new Promise((resolve) => {
            resolveRequested = resolve;
        });

        state[languageId] = {
            requested: false,
            generation: 0,
            requestedPromise,
            resolveRequested,
        };
    }

    return state;
}

function createFSSnapshotStateByLanguageId() {
    const state = {};

    for (const languageId of LANGUAGE_IDS) {
        state[languageId] = {
            workerGeneration: 0,
            appliedWorkerGeneration: 0,
            appliedVersion: 0,
            inFlight: null,
        };
    }

    return state;
}

function languageIdForWorkerLabel(label) {
    switch (label) {
        case 'typescript':
            return 'typescript';
        case 'javascript':
            return 'javascript';
        default:
            return null;
    }
}

function defaultDocumentPathForLanguageId(languageId) {
    switch (languageId) {
        case 'typescript':
            return 'main.ts';
        case 'javascript':
            return 'main.js';
        case 'json':
            return 'data.json';
        default:
            return 'main.txt';
    }
}

async function applySnapshotForLanguage(languageId, uri, snapshot) {
    const client = await getClient(languageId, uri);
    await client.applyFSSnapshot(snapshot);
}

async function getClient(languageId, uri) {
    const state = workerStateByLanguageId[languageId];
    await state.requestedPromise;

    const getWorker = (languageId === 'typescript')
        ? typescript.getTypeScriptWorker
        : typescript.getJavaScriptWorker;

    const workerAccessor = await getWorker();
    return await workerAccessor(uri);
}
