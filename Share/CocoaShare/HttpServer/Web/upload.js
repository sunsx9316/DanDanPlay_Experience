(function() {
    var C = window.__ANIX_CONFIG__ || { appName: "AniXPlayer", themeColor: "#14B409", lang: "zh-Hans", strings: {} };

    // ---- Apply theme & app name ----
    var root = document.documentElement;
    root.style.setProperty('--primary', C.themeColor);
    root.style.setProperty('--primary-dark', C.themeColor);
    root.style.setProperty('--success', C.themeColor);
    document.getElementById('appName').textContent = C.appName;

    // ---- I18n helper ----
    function t(key) {
        return C.strings[key] || key;
    }

    // ---- Apply i18n ----
    document.title = C.appName + ' - ' + t('title');
    document.getElementById('pageTitle').textContent = C.appName + ' - ' + t('title');
    document.getElementById('pageSubtitle').textContent = t('title');
    document.getElementById('dropTitle').textContent = t('dropTitle');
    document.getElementById('uploadBtnLabel').textContent = t('upload');
    document.getElementById('uploadFileItem').textContent = t('uploadFile');
    document.getElementById('uploadFolderItem').textContent = t('uploadFolder');
    document.getElementById('newFolderBtnLabel').textContent = t('newFolder');
    document.getElementById('loadingMsg').textContent = t('loading');

    // ============================================================
    //  Streaming SHA-256 (pure JS, works without HTTPS/Web Crypto)
    // ============================================================

    function SHA256() {
        var K = new Uint32Array([
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]);

        var H = new Uint32Array([0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]);
        var block = new Uint8Array(64);
        var blockView = new DataView(block.buffer);
        var buflen = 0;
        var totalLen = 0;

        function rotr(x, n) { return (x >>> n) | (x << (32 - n)); }
        function ch(x, y, z) { return (x & y) ^ (~x & z); }
        function maj(x, y, z) { return (x & y) ^ (x & z) ^ (y & z); }
        function sigma0(x) { return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22); }
        function sigma1(x) { return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25); }
        function gamma0(x) { return rotr(x, 7) ^ rotr(x, 18) ^ (x >>> 3); }
        function gamma1(x) { return rotr(x, 17) ^ rotr(x, 19) ^ (x >>> 10); }

        function processBlock() {
            var W = new Uint32Array(64);
            for (var t = 0; t < 16; t++) {
                W[t] = blockView.getUint32(t * 4, false);
            }
            for (var t = 16; t < 64; t++) {
                W[t] = (gamma1(W[t - 2]) + W[t - 7] + gamma0(W[t - 15]) + W[t - 16]) >>> 0;
            }

            var a = H[0], b = H[1], c = H[2], d = H[3];
            var e = H[4], f = H[5], g = H[6], h = H[7];

            for (var t = 0; t < 64; t++) {
                var T1 = (h + sigma1(e) + ch(e, f, g) + K[t] + W[t]) >>> 0;
                var T2 = (sigma0(a) + maj(a, b, c)) >>> 0;
                h = g; g = f; f = e; e = (d + T1) >>> 0;
                d = c; c = b; b = a; a = (T1 + T2) >>> 0;
            }

            H[0] = (H[0] + a) >>> 0; H[1] = (H[1] + b) >>> 0;
            H[2] = (H[2] + c) >>> 0; H[3] = (H[3] + d) >>> 0;
            H[4] = (H[4] + e) >>> 0; H[5] = (H[5] + f) >>> 0;
            H[6] = (H[6] + g) >>> 0; H[7] = (H[7] + h) >>> 0;
        }

        this.update = function(data) {
            totalLen += data.byteLength;
            var offset = 0;
            if (buflen > 0) {
                var space = 64 - buflen;
                var copyLen = Math.min(space, data.byteLength);
                block.set(new Uint8Array(data.buffer, data.byteOffset + offset, copyLen), buflen);
                buflen += copyLen;
                offset += copyLen;
                if (buflen === 64) {
                    processBlock();
                    buflen = 0;
                }
            }
            while (offset + 64 <= data.byteLength) {
                block.set(new Uint8Array(data.buffer, data.byteOffset + offset, 64));
                processBlock();
                offset += 64;
            }
            if (offset < data.byteLength) {
                var remaining = data.byteLength - offset;
                block.set(new Uint8Array(data.buffer, data.byteOffset + offset, remaining));
                buflen = remaining;
            }
        };

        this.digest = function() {
            var bitLen = totalLen * 8;
            // Pad with 0x80
            block[buflen] = 0x80;
            buflen++;
            if (buflen > 56) {
                block.fill(0, buflen, 64);
                processBlock();
                buflen = 0;
            }
            block.fill(0, buflen, 56);
            // Append bit length as big-endian 64-bit
            blockView.setUint32(56, Math.floor(bitLen / 0x100000000), false);
            blockView.setUint32(60, bitLen >>> 0, false);
            processBlock();

            var hex = '';
            for (var i = 0; i < 8; i++) {
                hex += ('0000000' + H[i].toString(16)).slice(-8);
            }
            return hex;
        };
    }

    // ---- Compute SHA-256 of a File (chunked, streaming) ----

    function readChunk(blob) {
        return new Promise(function(resolve, reject) {
            var reader = new FileReader();
            reader.onload = function() { resolve(new Uint8Array(reader.result)); };
            reader.onerror = function() { reject(reader.error); };
            reader.readAsArrayBuffer(blob);
        });
    }

    var MAX_HASH_SIZE = 200 * 1024 * 1024; // 200MB — 超过此大小只做大小校验

    async function computeSHA256(file) {
        if (file.size > MAX_HASH_SIZE) return null;
        var sha = new SHA256();
        var chunkSize = 1024 * 1024; // 1 MB
        var offset = 0;
        while (offset < file.size) {
            var end = Math.min(offset + chunkSize, file.size);
            var chunk = file.slice(offset, end);
            var buf = await readChunk(chunk);
            sha.update(buf);
            offset = end;
        }
        return sha.digest();
    }

    // ---- Upload concurrency limiter ----
    var MAX_CONCURRENT = 3;
    var uploadQueue = [];
    var activeUploads = 0;

    function enqueue(task) {
        uploadQueue.push(task);
        pumpQueue();
    }

    function pumpQueue() {
        while (activeUploads < MAX_CONCURRENT && uploadQueue.length > 0) {
            var task = uploadQueue.shift();
            activeUploads++;
            task().finally(function() {
                activeUploads--;
                pumpQueue();
            });
        }
    }

    // ---- Upload logic ----
    var dropzone = document.getElementById('dropzone');
    var fileInput = document.getElementById('fileInput');
    var folderInput = document.getElementById('folderInput');
    var uploadBtn = document.getElementById('uploadBtn');
    var uploadDropdown = document.getElementById('uploadDropdown');
    var uploadFileItem = document.getElementById('uploadFileItem');
    var uploadFolderItem = document.getElementById('uploadFolderItem');
    var fileList = document.getElementById('fileList');

    uploadBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        uploadDropdown.classList.toggle('show');
    });

    uploadFileItem.addEventListener('click', function(e) {
        e.stopPropagation();
        uploadDropdown.classList.remove('show');
        fileInput.click();
    });

    uploadFolderItem.addEventListener('click', function(e) {
        e.stopPropagation();
        uploadDropdown.classList.remove('show');
        folderInput.click();
    });

    document.addEventListener('click', function() {
        uploadDropdown.classList.remove('show');
    });

    dropzone.addEventListener('click', function() {
        fileInput.click();
    });

    fileInput.addEventListener('change', function() {
        if (fileInput.files.length > 0) {
            handleFiles(fileInput.files);
            fileInput.value = '';
        }
    });

    folderInput.addEventListener('change', function() {
        if (folderInput.files.length > 0) {
            handleFolderFiles(folderInput.files);
            folderInput.value = '';
        }
    });

    dropzone.addEventListener('dragover', function(e) {
        e.preventDefault();
        e.stopPropagation();
        dropzone.classList.add('drag-over');
    });

    dropzone.addEventListener('dragleave', function(e) {
        e.preventDefault();
        e.stopPropagation();
        dropzone.classList.remove('drag-over');
    });

    dropzone.addEventListener('drop', function(e) {
        e.preventDefault();
        e.stopPropagation();
        dropzone.classList.remove('drag-over');

        var items = e.dataTransfer.items;
        if (items && items.length > 0) {
            handleDropItems(items);
        }
    });

    function formatSize(bytes) {
        if (bytes === 0) return '0 B';
        var k = 1024;
        var sizes = ['B', 'KB', 'MB', 'GB'];
        var i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }

    function handleDropItems(items) {
        var pending = [];
        for (var i = 0; i < items.length; i++) {
            var entry = items[i].webkitGetAsEntry();
            if (!entry) continue;
            pending.push(processDropEntry(entry));
        }
        Promise.all(pending);
    }

    function processDropEntry(entry) {
        if (entry.isFile) {
            return new Promise(function(resolve) {
                entry.file(function(file) {
                    fileList.classList.remove('empty');
                    // 立即展示为"排队中"
                    var item = createFileItem(file, '');
                    item.querySelector('.file-status').textContent = '⏳ ' + t('waiting');
                    fileList.insertBefore(item, fileList.firstChild);
                    enqueue(function() { return uploadFile(file, '', item); });
                    resolve();
                });
            });
        } else if (entry.isDirectory) {
            return traverseEntry(entry, '').then(function(files) {
                if (files.length > 0) {
                    fileList.classList.remove('empty');
                    uploadFolderContents(files, entry.name);
                }
            });
        }
    }

    function traverseEntry(entry, basePath) {
        return new Promise(function(resolve) {
            if (entry.isFile) {
                entry.file(function(file) {
                    resolve([{ file: file, relativePath: basePath + file.name }]);
                });
            } else if (entry.isDirectory) {
                readAllEntries(entry).then(function(entries) {
                    var subTasks = [];
                    var dirPath = basePath + entry.name + '/';
                    for (var i = 0; i < entries.length; i++) {
                        subTasks.push(traverseEntry(entries[i], dirPath));
                    }
                    Promise.all(subTasks).then(function(results) {
                        var files = [];
                        results.forEach(function(r) { files = files.concat(r); });
                        resolve(files);
                    });
                });
            } else {
                resolve([]);
            }
        });
    }

    function readAllEntries(dirEntry) {
        return new Promise(function(resolve) {
            var reader = dirEntry.createReader();
            var allEntries = [];
            function readBatch() {
                reader.readEntries(function(entries) {
                    if (entries.length === 0) {
                        resolve(allEntries);
                    } else {
                        allEntries = allEntries.concat(Array.prototype.slice.call(entries));
                        readBatch();
                    }
                });
            }
            readBatch();
        });
    }

    function handleFolderFiles(files) {
        var groups = {};
        for (var i = 0; i < files.length; i++) {
            var f = files[i];
            var relativePath = f.webkitRelativePath || f.name;
            var rootName = relativePath.split('/')[0] || f.name;
            if (!groups[rootName]) groups[rootName] = [];
            groups[rootName].push({ file: f, relativePath: relativePath });
        }
        fileList.classList.remove('empty');
        var keys = Object.keys(groups);
        for (var k = 0; k < keys.length; k++) {
            uploadFolderContents(groups[keys[k]], keys[k]);
        }
    }

    function handleFiles(files) {
        fileList.classList.remove('empty');
        for (var i = 0; i < files.length; i++) {
            (function(f) {
                // 立即展示所有文件为"排队中"
                var item = createFileItem(f, '');
                item.querySelector('.file-status').textContent = '⏳ ' + t('waiting');
                fileList.insertBefore(item, fileList.firstChild);
                enqueue(function() { return uploadFile(f, '', item); });
            })(files[i]);
        }
    }

    function getUploadPath(fileName, relativePath) {
        var dir = (window.__fmCurrentPath || '/');
        var base = relativePath || fileName;
        return dir === '/' ? '/' + base : dir + '/' + base;
    }

    // ---- Hashing indicator helpers ----

    function showHashing(item) {
        var metaEl = item.querySelector('.file-meta');
        metaEl.textContent = t('loading') + ' SHA-256...';
    }

    // ---- Upload (async — hash first, then send) ----

    async function uploadFile(file, relativePath, existingItem) {
        var item = existingItem || createFileItem(file, relativePath);
        if (!existingItem) {
            fileList.insertBefore(item, fileList.firstChild);
        }

        // Compute SHA-256 before upload
        showHashing(item);
        var checksum;
        try {
            checksum = await computeSHA256(file);
        } catch (e) {
            console.error('[sha256] failed:', e);
            checksum = null;
        }

        return new Promise(function(resolve) {
            var xhr = new XMLHttpRequest();
            var formData = new FormData();
            formData.append('file', file);
            formData.append('path', getUploadPath(file.name, relativePath));
            formData.append('size', file.size);
            if (checksum) formData.append('checksum', checksum);

            var lastLoaded = 0;
            var lastTime = Date.now();

            xhr.upload.addEventListener('progress', function(e) {
                if (e.lengthComputable) {
                    var percent = Math.round((e.loaded / e.total) * 100);
                    var now = Date.now();
                    var timeDiff = (now - lastTime) / 1000;
                    var bytesDiff = e.loaded - lastLoaded;
                    var speed = timeDiff > 0 ? bytesDiff / timeDiff : 0;
                    lastLoaded = e.loaded;
                    lastTime = now;
                    updateProgress(item, percent, e.loaded, e.total, speed);
                }
            });

            xhr.addEventListener('load', function() {
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        var verified = resp.files && resp.files[0] && resp.files[0].verified;
                        markComplete(item, file.size, verified);
                    } catch (e) {
                        markComplete(item, file.size, false);
                    }
                } else {
                    console.error('[file] server error:', xhr.status, file.name);
                    markError(item, t('serverError'));
                }
                resolve();
            });

            xhr.addEventListener('error', function() {
                console.error('[file] network error:', file.name);
                markError(item, t('networkError'));
                resolve();
            });

            xhr.open('POST', '/upload');
            xhr.send(formData);
        });
    }

    function uploadFolderContents(fileList_in, folderName) {
        var totalSize = 0;
        for (var i = 0; i < fileList_in.length; i++) {
            totalSize += fileList_in[i].file.size;
        }

        var totalFiles = fileList_in.length;
        var item = createFolderItem(folderName, totalSize, totalFiles);
        fileList.insertBefore(item, fileList.firstChild);

        var completedBytes = 0;
        var completedFiles = 0;
        var failedCount = 0;

        async function uploadNext(index) {
            if (index >= fileList_in.length) {
                markFolderComplete(item, totalSize, totalFiles, failedCount);
                return;
            }

            var f = fileList_in[index];

            var checksum;
            try {
                checksum = await computeSHA256(f.file);
            } catch (e) {
                checksum = null;
            }

            var xhr = new XMLHttpRequest();
            var formData = new FormData();
            formData.append('file', f.file);
            formData.append('path', getUploadPath(f.file.name, f.relativePath));
            formData.append('total', totalFiles);
            formData.append('size', f.file.size);
            if (checksum) formData.append('checksum', checksum);

            xhr.addEventListener('load', function() {
                completedFiles++;
                completedBytes += f.file.size;

                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        if (!resp.files || !resp.files[0] || !resp.files[0].verified) {
                            failedCount++;
                        }
                    } catch (e) {
                        failedCount++;
                    }
                } else {
                    failedCount++;
                }

                updateFolderProgress(item, completedBytes, totalSize, completedFiles, totalFiles);
                uploadNext(index + 1);
            });

            xhr.addEventListener('error', function() {
                completedFiles++;
                completedBytes += f.file.size;
                failedCount++;
                updateFolderProgress(item, completedBytes, totalSize, completedFiles, totalFiles);
                uploadNext(index + 1);
            });

            xhr.open('POST', '/upload');
            xhr.send(formData);
        }

        uploadNext(0);
    }

    // ---- UI Helpers ----

    function createFolderItem(folderName, totalSize, totalFiles) {
        var div = document.createElement('div');
        div.className = 'file-item';
        div.innerHTML =
            '<div class="file-header">' +
                '<div class="file-info">' +
                    '<div class="file-icon uploading">' +
                        '<svg viewBox="0 0 24 24"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>' +
                    '</div>' +
                    '<div style="min-width:0;flex:1;">' +
                        '<div class="file-name">' + escapeHtml(folderName) + '/</div>' +
                        '<div class="file-meta">' + formatSize(totalSize) + ' · ' + totalFiles + ' ' + t('files') + '</div>' +
                    '</div>' +
                '</div>' +
                '<div class="file-status uploading">0 / ' + totalFiles + '</div>' +
            '</div>' +
            '<div class="progress-bar"><div class="progress-fill" style="width:0%"></div></div>';
        return div;
    }

    function updateFolderProgress(item, completedBytes, totalSize, completedFiles, totalFiles) {
        var percent = totalSize > 0 ? Math.round((completedBytes / totalSize) * 100) : 100;
        var progressFill = item.querySelector('.progress-fill');
        progressFill.style.width = percent + '%';

        var statusEl = item.querySelector('.file-status');
        statusEl.textContent = completedFiles + ' / ' + totalFiles;

        var metaEl = item.querySelector('.file-meta');
        metaEl.textContent = formatSize(completedBytes) + ' / ' + formatSize(totalSize) + ' · ' + totalFiles + ' ' + t('files');
    }

    var refreshTimer = null;
    function scheduleRefresh() {
        if (refreshTimer) clearTimeout(refreshTimer);
        refreshTimer = setTimeout(function() {
            if (window.__fmRefresh) window.__fmRefresh();
        }, 300);
    }

    function markFolderComplete(item, totalSize, totalFiles, failedCount) {
        var iconEl = item.querySelector('.file-icon');
        var statusEl = item.querySelector('.file-status');
        var progressFill = item.querySelector('.progress-fill');
        var metaEl = item.querySelector('.file-meta');

        if (failedCount === 0) {
            iconEl.classList.remove('uploading');
            iconEl.classList.add('success');
            iconEl.innerHTML = '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>';
            statusEl.textContent = '✓ ' + t('complete');
            statusEl.classList.remove('uploading');
            statusEl.classList.add('success');
            progressFill.classList.add('success');
        } else {
            iconEl.classList.remove('uploading');
            iconEl.classList.add('error');
            iconEl.innerHTML = '<svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';
            statusEl.textContent = '⚠ ' + failedCount + ' ' + t('files') + ' failed';
            statusEl.classList.remove('uploading');
            statusEl.classList.add('error');
            progressFill.classList.add('error');
        }

        progressFill.style.width = '100%';
        metaEl.textContent = formatSize(totalSize) + ' · ' + totalFiles + ' ' + t('files');

        scheduleRefresh();
    }

    function createFileItem(file, relativePath) {
        var div = document.createElement('div');
        div.className = 'file-item';
        div.innerHTML =
            '<div class="file-header">' +
                '<div class="file-info">' +
                    '<div class="file-icon uploading">' +
                        '<svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>' +
                    '</div>' +
                    '<div style="min-width:0;flex:1;">' +
                        '<div class="file-name">' + escapeHtml(file.name) + '</div>' +
                        '<div class="file-meta">' + formatSize(file.size) + '</div>' +
                    '</div>' +
                '</div>' +
                '<div class="file-status uploading">0%</div>' +
            '</div>' +
            '<div class="progress-bar"><div class="progress-fill" style="width:0%"></div></div>';
        return div;
    }

    function escapeHtml(str) {
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(str));
        return div.innerHTML;
    }

    function updateProgress(item, percent, loaded, total, speed) {
        var statusEl = item.querySelector('.file-status');
        var progressFill = item.querySelector('.progress-fill');
        var metaEl = item.querySelector('.file-meta');
        statusEl.textContent = percent + '%';
        progressFill.style.width = percent + '%';
        var speedStr = speed > 0 ? '  ' + formatSize(speed) + '/s' : '';
        metaEl.textContent = formatSize(loaded) + ' / ' + formatSize(total) + speedStr;
    }

    function markComplete(item, fileSize, verified) {
        var iconEl = item.querySelector('.file-icon');
        var statusEl = item.querySelector('.file-status');
        var progressFill = item.querySelector('.progress-fill');
        var metaEl = item.querySelector('.file-meta');

        iconEl.classList.remove('uploading');
        progressFill.style.width = '100%';
        metaEl.textContent = formatSize(fileSize);

        if (verified) {
            iconEl.classList.add('success');
            iconEl.innerHTML = '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>';
            statusEl.textContent = '✓ ' + t('complete');
            statusEl.classList.remove('uploading');
            statusEl.classList.add('success');
            progressFill.classList.add('success');
        } else {
            iconEl.classList.add('error');
            iconEl.innerHTML = '<svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';
            statusEl.textContent = '⚠ ' + t('complete') + ' - unverified';
            statusEl.classList.remove('uploading');
            statusEl.classList.add('error');
            progressFill.classList.add('error');
        }

        scheduleRefresh();
    }

    function markError(item, reason) {
        var iconEl = item.querySelector('.file-icon');
        var statusEl = item.querySelector('.file-status');
        var progressFill = item.querySelector('.progress-fill');
        iconEl.classList.remove('uploading');
        iconEl.classList.add('error');
        iconEl.innerHTML = '<svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';
        statusEl.classList.remove('uploading');
        statusEl.classList.add('error');
        statusEl.textContent = reason;
        progressFill.classList.add('error');
    }
})();
