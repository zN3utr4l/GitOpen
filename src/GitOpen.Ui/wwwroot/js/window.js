// Drag and resize helpers for chromeless Photino windows.
// Sends 'drag:dx:dy' and 'resize:<edge>:dx:dy' messages to the host
// via window.external.sendMessage. The host (Program.cs) interprets
// each delta and updates the window position / size.

(function () {
    let drag = null;
    let resize = null;

    function send(msg) {
        if (window.external && window.external.sendMessage) {
            window.external.sendMessage(msg);
        }
    }

    function startDrag(e) {
        if (e.button !== 0) return;
        // Don't start drag when the user actually clicked a button or another
        // interactive element inside the title bar.
        if (e.target.closest('button, input, a, [data-no-drag]')) return;

        drag = { x: e.screenX, y: e.screenY };
        document.addEventListener('pointermove', onDragMove);
        document.addEventListener('pointerup', endDrag, { once: true });
        document.addEventListener('pointercancel', endDrag, { once: true });
        try { e.target.setPointerCapture && e.target.setPointerCapture(e.pointerId); } catch (_) { }
    }

    function onDragMove(e) {
        if (!drag) return;
        const dx = e.screenX - drag.x;
        const dy = e.screenY - drag.y;
        if (dx !== 0 || dy !== 0) {
            send('drag:' + dx + ':' + dy);
            drag.x = e.screenX;
            drag.y = e.screenY;
        }
    }

    function endDrag() {
        drag = null;
        document.removeEventListener('pointermove', onDragMove);
    }

    function startResize(edge, e) {
        if (e.button !== 0) return;
        resize = { edge: edge, x: e.screenX, y: e.screenY };
        document.addEventListener('pointermove', onResizeMove);
        document.addEventListener('pointerup', endResize, { once: true });
        document.addEventListener('pointercancel', endResize, { once: true });
        try { e.target.setPointerCapture && e.target.setPointerCapture(e.pointerId); } catch (_) { }
        e.preventDefault();
        e.stopPropagation();
    }

    function onResizeMove(e) {
        if (!resize) return;
        const dx = e.screenX - resize.x;
        const dy = e.screenY - resize.y;
        if (dx !== 0 || dy !== 0) {
            send('resize:' + resize.edge + ':' + dx + ':' + dy);
            resize.x = e.screenX;
            resize.y = e.screenY;
        }
    }

    function endResize() {
        resize = null;
        document.removeEventListener('pointermove', onResizeMove);
    }

    function doubleClickMaximize(e) {
        if (e.target.closest('button, input, a, [data-no-drag]')) return;
        send('toggleMax');
    }

    window.gitOpen = {
        startDrag: startDrag,
        startResize: startResize,
        doubleClickMaximize: doubleClickMaximize
    };
})();
