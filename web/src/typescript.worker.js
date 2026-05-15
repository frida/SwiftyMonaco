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

        this._languageService.cleanupSemanticCache();
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
        const dir = normalizeDirUri(path);
        if (snapshotDirs.has(dir)) {
            return true;
        }
        return this._mirrorModelDirs().has(dir);
    }

    getDirectories(path) {
        const dir = normalizeDirUri(path);
        const { directories } = this._getFileSystemEntries(dir);
        return directories.map((name) => joinUri(dir, name));
    }

    async getEncodedSemanticClassifications(fileName, start, length, format) {
        return this._languageService.getEncodedSemanticClassifications(
            fileName,
            { start, length },
            format,
        );
    }

    readDirectory(path, extensions, excludes, includes, depth) {
        const dir = normalizeDirUri(path);
        return ts.matchFiles(
            dir,
            extensions,
            excludes,
            includes,
            true,
            dir,
            depth,
            (d) => this._getFileSystemEntries(d),
            (p) => p
        );
    }

    _getFileSystemEntries(dirUri) {
        const dir = normalizeDirUri(dirUri);
        const snapshot = snapshotGetFileSystemEntries(dir);
        const seenFiles = new Set(snapshot.files);
        const seenDirs = new Set(snapshot.directories);
        const files = [...snapshot.files];
        const directories = [...snapshot.directories];

        for (const model of this._ctx.getMirrorModels()) {
            const uri = model.uri.toString();
            if (!uri.startsWith(dir)) {
                continue;
            }
            const rest = uri.slice(dir.length);
            const slash = rest.indexOf('/');
            if (slash === -1) {
                if (!seenFiles.has(rest)) {
                    seenFiles.add(rest);
                    files.push(rest);
                }
            } else {
                const childDir = rest.slice(0, slash);
                if (!seenDirs.has(childDir)) {
                    seenDirs.add(childDir);
                    directories.push(childDir);
                }
            }
        }

        return { files, directories };
    }

    _mirrorModelDirs() {
        const dirs = new Set();
        for (const model of this._ctx.getMirrorModels()) {
            const uri = model.uri.toString();
            let cursor = parentDirUri(uri);
            while (cursor !== WORKSPACE_ROOT_URI) {
                if (dirs.has(cursor)) {
                    break;
                }
                dirs.add(cursor);
                cursor = parentDirUri(cursor.slice(0, -1));
            }
            dirs.add(WORKSPACE_ROOT_URI);
        }
        return dirs;
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
