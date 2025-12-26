import { start } from 'monaco-editor/esm/vs/editor/editor.worker.start.js';
import { initialize } from 'monaco-editor/esm/vs/common/initialize.js';
import { TypeScriptWorker } from 'monaco-editor/esm/vs/language/typescript/ts.worker.js';
import { typescript as ts } from 'monaco-editor/esm/vs/language/typescript/lib/typescriptServices.js';

const WORKSPACE_ROOT_URI = 'file:///workspace/';

let snapshotVersion = 0;
let snapshotFilesText = new Map();
let snapshotDirs = new Set();
let snapshotDirChildren = new Map();

self.onmessage = () => {
    initialize((ctx, createData) => {
        return new SwiftyMonacoTypeScriptWorker(ctx, createData);
    });
};

class SwiftyMonacoTypeScriptWorker extends TypeScriptWorker {
    applyFSSnapshot(snapshot, activeFile) {
        snapshotVersion = snapshot.version;

        snapshotFilesText = new Map();
        snapshotDirs = new Set();
        snapshotDirChildren = new Map();

        ensureDir(WORKSPACE_ROOT_URI);

        for (const { path, text } of snapshot.files) {
            snapshotFilesText.set(path, text);

            const dir = parentDirUri(path);
            ensureDir(dir);

            const leafName = path.slice(dir.length);
            snapshotDirChildren.get(dir).add(leafName);

            let current = dir;
            while (current !== WORKSPACE_ROOT_URI) {
                const parent = parentDirUri(current.slice(0, -1));
                ensureDir(parent);

                const childDirName = current.slice(parent.length, current.length - 1);
                snapshotDirChildren.get(parent).add(childDirName);

                current = parent;
            }
        }
    }

    getCurrentDirectory() {
        return WORKSPACE_ROOT_URI;
    }

    getScriptVersion(fileName) {
        if (snapshotHasFile(fileName)) {
            return String(snapshotVersion);
        }
        return super.getScriptVersion(fileName);
    }

    _getScriptText(fileName) {
        if (snapshotHasFile(fileName)) {
            return snapshotReadFile(fileName);
        }
        return super._getScriptText(fileName);
    }

    readFile(path) {
        return this._getScriptText(path);
    }

    fileExists(path) {
        return this._getScriptText(path) !== undefined;
    }

    directoryExists(path) {
        return snapshotDirectoryExists(path);
    }

    getDirectories(path) {
        const dir = normalizeDirUri(path);
        const { directories } = snapshotGetFileSystemEntries(dir);
        return directories.map((name) => joinUri(dir, name));
    }

    readDirectory(path, extensions, excludes, includes, depth) {
        return snapshotReadDirectoryUsingTSMatchFiles(path, extensions, excludes, includes, depth);
    }
}

function snapshotHasFile(fileUri) {
    return snapshotFilesText.has(fileUri);
}

function snapshotReadFile(fileUri) {
    return snapshotFilesText.get(fileUri);
}

function snapshotDirectoryExists(dirUri) {
    return snapshotDirs.has(normalizeDirUri(dirUri));
}

function snapshotGetFileSystemEntries(dirUri) {
    const dir = normalizeDirUri(dirUri);
    const children = snapshotDirChildren.get(dir);

    const files = [];
    const directories = [];

    for (const name of children ?? []) {
        const full = joinUri(dir, name);
        if (snapshotHasFile(full)) {
            files.push(name);
            continue;
        }
        if (snapshotDirectoryExists(full)) {
            directories.push(name);
        } else if (snapshotDirectoryExists(`${full}/`)) {
            directories.push(name);
        }
    }

    return { files, directories };
}

function snapshotReadDirectoryUsingTSMatchFiles(path, extensions, excludes, includes, depth) {
    const currentDirectory = normalizeDirUri(path);
    const useCaseSensitive = true;

    return ts.matchFiles(
        currentDirectory,
        extensions,
        excludes,
        includes,
        useCaseSensitive,
        currentDirectory,
        depth,
        (dir) => snapshotGetFileSystemEntries(dir),
        (p) => p
    );
}

function normalizeDirUri(dirUri) {
    if (dirUri.endsWith('/')) {
        return dirUri;
    }
    return `${dirUri}/`;
}

function parentDirUri(fileUri) {
    const idx = fileUri.lastIndexOf('/');
    if (idx === -1) {
        return WORKSPACE_ROOT_URI;
    }
    return normalizeDirUri(fileUri.slice(0, idx));
}

function joinUri(dirUri, childName) {
    const base = normalizeDirUri(dirUri);
    return `${base}${childName}`;
}

function ensureDir(dirUri) {
    const d = normalizeDirUri(dirUri);
    snapshotDirs.add(d);
    if (!snapshotDirChildren.has(d)) {
        snapshotDirChildren.set(d, new Set());
    }
}
