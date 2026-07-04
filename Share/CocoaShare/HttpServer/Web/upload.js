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
                    uploadFile(file, '');
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
            uploadFile(files[i], '');
        }
    }

    function uploadFile(file, relativePath) {
        var item = createFileItem(file, relativePath);
        fileList.insertBefore(item, fileList.firstChild);

        var xhr = new XMLHttpRequest();
        var formData = new FormData();
        formData.append('file', file);
        if (relativePath) formData.append('path', relativePath);

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
                markComplete(item, file.size);
            } else {
                console.error('[file] server error:', xhr.status, file.name);
                markError(item, t('serverError'));
            }
        });

        xhr.addEventListener('error', function() {
            console.error('[file] network error:', file.name);
            markError(item, t('networkError'));
        });

        xhr.open('POST', '/upload');
        xhr.send(formData);
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

        function uploadNext(index) {
            if (index >= fileList_in.length) {
                markFolderComplete(item, totalSize, totalFiles);
                return;
            }

            var f = fileList_in[index];
            var xhr = new XMLHttpRequest();
            var formData = new FormData();
            formData.append('file', f.file);
            formData.append('path', f.relativePath);
            formData.append('total', totalFiles);

            xhr.addEventListener('load', function() {
                completedFiles++;
                completedBytes += f.file.size;
                updateFolderProgress(item, completedBytes, totalSize, completedFiles, totalFiles);

                if (xhr.status === 200) {
                    uploadNext(index + 1);
                } else {
                    console.error('[folder] server error:', xhr.status, f.relativePath);
                    uploadNext(index + 1);
                }
            });

            xhr.addEventListener('error', function() {
                console.error('[folder] network error:', f.relativePath);
                completedFiles++;
                completedBytes += f.file.size;
                updateFolderProgress(item, completedBytes, totalSize, completedFiles, totalFiles);
                uploadNext(index + 1);
            });

            xhr.open('POST', '/upload');
            xhr.send(formData);
        }

        uploadNext(0);
    }

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

    function markFolderComplete(item, totalSize, totalFiles) {
        var iconEl = item.querySelector('.file-icon');
        var statusEl = item.querySelector('.file-status');
        var progressFill = item.querySelector('.progress-fill');
        var metaEl = item.querySelector('.file-meta');

        iconEl.classList.remove('uploading');
        iconEl.classList.add('success');
        iconEl.innerHTML = '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>';

        statusEl.textContent = t('complete');
        statusEl.classList.remove('uploading');
        statusEl.classList.add('success');

        progressFill.classList.add('success');
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

    function markComplete(item, fileSize) {
        var iconEl = item.querySelector('.file-icon');
        var statusEl = item.querySelector('.file-status');
        var progressFill = item.querySelector('.progress-fill');
        var metaEl = item.querySelector('.file-meta');
        iconEl.classList.remove('uploading');
        iconEl.classList.add('success');
        iconEl.innerHTML = '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>';
        statusEl.classList.remove('uploading');
        statusEl.classList.add('success');
        statusEl.textContent = t('complete');
        progressFill.classList.add('success');
        progressFill.style.width = '100%';
        metaEl.textContent = formatSize(fileSize);

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
