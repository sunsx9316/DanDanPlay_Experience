(function() {
    var C = window.__ANIX_CONFIG__ || { strings: {} };
    function t(key) { return C.strings[key] || key; }

    var currentPath = '/';
    var pendingDeletePath = null;
    var pendingRenamePath = null;

    // ---- DOM refs ----
    var breadcrumbEl, fileListEl, newFolderBtn;
    var modalOverlay, modalTitle, modalBody, modalCancel, modalConfirm;
    var renameInput, deleteMsg, mkdirInput;

    function $(id) { return document.getElementById(id); }

    function hashPath() {
        var h = location.hash;
        if (h.startsWith('#/')) {
            return decodeURIComponent(h.slice(1));
        }
        return '/';
    }

    function updateHash(path) {
        var h = '#' + path;
        if (location.hash !== h) {
            location.hash = h;
        }
    }

    function init() {
        breadcrumbEl = $('breadcrumb');
        fileListEl  = $('fileManagerList');
        newFolderBtn = $('newFolderBtn');

        modalOverlay = $('modalOverlay');
        modalTitle   = $('modalTitle');
        modalBody    = $('modalBody');
        modalCancel  = $('modalCancel');
        modalConfirm = $('modalConfirm');

        if (!fileListEl) return;

        newFolderBtn.addEventListener('click', showNewFolderModal);
        modalCancel.addEventListener('click', hideModal);
        modalOverlay.addEventListener('click', function(e) {
            if (e.target === modalOverlay) hideModal();
        });

        window.addEventListener('hashchange', function() {
            var p = hashPath();
            if (p !== currentPath) {
                loadFiles(p);
            }
        });

        loadFiles(hashPath());

        window.__fmRefresh = function() {
            loadFiles(currentPath);
        };
    }

    // ---- API helpers ----

    function loadFiles(path) {
        currentPath = path;
        updateHash(path);
        var url = '/api/files?path=' + encodeURIComponent(path);
        fetch(url)
            .then(function(r) { return r.json(); })
            .then(function(data) {
                if (data.success) {
                    renderBreadcrumb(data.path);
                    renderFileList(data.files);
                } else {
                    fileListEl.innerHTML = '<div class="empty-dir">' + escapeHtml(data.error || t('loadError')) + '</div>';
                }
            })
            .catch(function() {
                fileListEl.innerHTML = '<div class="empty-dir">' + t('loadError') + '</div>';
            });
    }

    // ---- Breadcrumb ----

    function renderBreadcrumb(path) {
        var parts = path.split('/').filter(function(p) { return p.length > 0; });
        var html = '<span class="breadcrumb-item" data-path="/">Home</span>';
        var accumulated = '';
        for (var i = 0; i < parts.length; i++) {
            accumulated += '/' + parts[i];
            html += '<span class="breadcrumb-sep">/</span>';
            html += '<span class="breadcrumb-item" data-path="' + accumulated + '">' + escapeHtml(decodeURIComponent(parts[i])) + '</span>';
        }
        breadcrumbEl.innerHTML = html;

        var items = breadcrumbEl.querySelectorAll('.breadcrumb-item');
        for (var j = 0; j < items.length; j++) {
            (function(p) {
                items[j].addEventListener('click', function() { loadFiles(p); });
            })(items[j].getAttribute('data-path'));
        }
    }

    // ---- File List ----

    function renderFileList(files) {
        if (files.length === 0) {
            fileListEl.innerHTML = '<div class="empty-dir">' + t('emptyDir') + '</div>';
            return;
        }

        var html = '';
        for (var i = 0; i < files.length; i++) {
            var f = files[i];
            var sizeStr = f.isDirectory ? '' : formatSize(f.size);
            var dateStr = formatDate(f.modified);
            var itemClass = f.isDirectory ? ' is-dir' : '';

            html += '<div class="fm-item' + itemClass + '" data-name="' + attrEscape(f.name) + '" data-isdir="' + f.isDirectory + '">' +
                '<div class="fm-item-main">' +
                    '<div class="fm-item-icon">' + fileIcon(f.isDirectory) + '</div>' +
                    '<div class="fm-item-info">' +
                        '<div class="fm-item-name">' + escapeHtml(f.name) + '</div>' +
                        '<div class="fm-item-meta">' + (f.isDirectory ? t('folder') : (sizeStr + (dateStr ? ' · ' + dateStr : ''))) + '</div>' +
                    '</div>' +
                '</div>' +
                '<div class="fm-item-actions">' +
                    '<button class="fm-action-btn rename-btn" title="' + t('rename') + '">' + renameIcon() + '</button>' +
                    '<button class="fm-action-btn delete-btn" title="' + t('delete') + '">' + deleteIcon() + '</button>' +
                '</div>' +
            '</div>';
        }

        fileListEl.innerHTML = html;

        // Wire up click handlers
        var items = fileListEl.querySelectorAll('.fm-item');
        for (var j = 0; j < items.length; j++) {
            (function() {
                var el = items[j];
                var name = el.getAttribute('data-name');
                var isDir = el.getAttribute('data-isdir') === 'true';

                el.querySelector('.fm-item-main').addEventListener('click', function() {
                    if (isDir) {
                        var newPath = currentPath === '/' ? '/' + name : currentPath + '/' + name;
                        loadFiles(newPath);
                    }
                });

                el.querySelector('.rename-btn').addEventListener('click', function(e) {
                    e.stopPropagation();
                    showRenameModal(name);
                });

                el.querySelector('.delete-btn').addEventListener('click', function(e) {
                    e.stopPropagation();
                    showDeleteModal(name);
                });
            })();
        }
    }

    // ---- Modals ----

    var modalAction = null;

    function showModal(title, bodyHtml, confirmText, action) {
        modalTitle.textContent = title;
        modalBody.innerHTML = bodyHtml;
        modalConfirm.textContent = confirmText;
        modalAction = action;
        modalConfirm.style.display = 'inline-block';
        modalOverlay.style.display = 'flex';
        modalConfirm.onclick = function() {
            if (modalAction) modalAction();
        };
    }

    function hideModal() {
        modalOverlay.style.display = 'none';
        modalAction = null;
    }

    function showNewFolderModal() {
        showModal(
            t('newFolder'),
            '<input type="text" id="mkdirInput" class="modal-input" placeholder="' + t('folderName') + '" maxlength="128" autofocus>',
            t('create'),
            confirmMkdir
        );
        setTimeout(function() {
            var inp = $('mkdirInput');
            if (inp) inp.focus();
        }, 100);
    }

    function showRenameModal(name) {
        pendingRenamePath = currentPath === '/' ? '/' + name : currentPath + '/' + name;
        showModal(
            t('rename'),
            '<input type="text" id="renameInput" class="modal-input" value="' + escapeHtml(name) + '" maxlength="256" autofocus>',
            t('confirm'),
            confirmRename
        );
        setTimeout(function() {
            var inp = $('renameInput');
            if (inp) { inp.focus(); inp.select(); }
        }, 100);
    }

    function showDeleteModal(name) {
        pendingDeletePath = currentPath === '/' ? '/' + name : currentPath + '/' + name;
        showModal(
            t('delete'),
            '<p id="deleteMsg">' + t('deleteConfirm') + ' <strong>' + escapeHtml(name) + '</strong> ?</p>',
            t('delete'),
            confirmDelete
        );
        modalConfirm.style.background = 'var(--error)';
    }

    function hideModalAndReset() {
        hideModal();
        modalConfirm.style.background = '';
    }

    // ---- API Actions ----

    function confirmMkdir() {
        var inp = $('mkdirInput');
        var name = inp ? inp.value.trim() : '';
        if (!name) return;

        fetch('/api/mkdir', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ path: currentPath, name: name })
        })
        .then(function(r) { return r.json(); })
        .then(function(data) {
            if (data.success) {
                hideModal();
                loadFiles(currentPath);
            } else {
                alert(data.error || t('mkdirError'));
            }
        })
        .catch(function() {
            alert(t('mkdirError'));
        });
    }

    function confirmRename() {
        var inp = $('renameInput');
        var newName = inp ? inp.value.trim() : '';
        if (!newName) return;

        fetch('/api/rename', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ path: pendingRenamePath, newName: newName })
        })
        .then(function(r) { return r.json(); })
        .then(function(data) {
            if (data.success) {
                hideModalAndReset();
                loadFiles(currentPath);
            } else {
                alert(data.error || t('renameError'));
            }
        })
        .catch(function() {
            alert(t('renameError'));
        });
    }

    function confirmDelete() {
        if (!pendingDeletePath) return;

        fetch('/api/delete', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ path: pendingDeletePath })
        })
        .then(function(r) { return r.json(); })
        .then(function(data) {
            if (data.success) {
                hideModalAndReset();
                loadFiles(currentPath);
            } else {
                alert(data.error || t('deleteError'));
                hideModalAndReset();
            }
        })
        .catch(function() {
            alert(t('deleteError'));
            hideModalAndReset();
        });
    }

    // ---- Utilities ----

    function formatSize(bytes) {
        if (bytes === 0) return '0 B';
        var k = 1024;
        var sizes = ['B', 'KB', 'MB', 'GB'];
        var i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }

    function formatDate(ts) {
        if (!ts) return '';
        var d = new Date(ts * 1000);
        var y = d.getFullYear();
        var m = ('0' + (d.getMonth() + 1)).slice(-2);
        var day = ('0' + d.getDate()).slice(-2);
        var h = ('0' + d.getHours()).slice(-2);
        var min = ('0' + d.getMinutes()).slice(-2);
        return y + '-' + m + '-' + day + ' ' + h + ':' + min;
    }

    function escapeHtml(str) {
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function attrEscape(str) {
        return str.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    function fileIcon(isDir) {
        if (isDir) {
            return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>';
        }
        return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>';
    }

    function renameIcon() {
        return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>';
    }

    function deleteIcon() {
        return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>';
    }

    // ---- Kick off ----
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
