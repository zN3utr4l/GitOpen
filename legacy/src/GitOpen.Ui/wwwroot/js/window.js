// Drag and resize helpers for chromeless Photino windows.
// Uses requestAnimationFrame to coalesce pointermove events into at most
// one host message per frame so the WebView <-> native bridge does not
// become the bottleneck.

(function () {
    function send(msg) {
        if (window.external && window.external.sendMessage) {
            window.external.sendMessage(msg);
        }
    }

    function startTracker(e, onFlush, opts) {
        if (e.button !== 0) return;
        if (opts && opts.guardInteractive
            && e.target.closest('button, input, a, [data-no-drag]')) return;

        let lastX = e.screenX;
        let lastY = e.screenY;
        let dx = 0, dy = 0;
        let raf = null;

        function flush() {
            raf = null;
            if (dx !== 0 || dy !== 0) {
                onFlush(dx, dy);
                dx = 0;
                dy = 0;
            }
        }

        function move(ev) {
            dx += ev.screenX - lastX;
            dy += ev.screenY - lastY;
            lastX = ev.screenX;
            lastY = ev.screenY;
            if (raf === null) raf = requestAnimationFrame(flush);
        }

        function up() {
            if (raf !== null) cancelAnimationFrame(raf);
            flush();
            document.removeEventListener('pointermove', move);
        }

        document.addEventListener('pointermove', move);
        document.addEventListener('pointerup', up, { once: true });
        document.addEventListener('pointercancel', up, { once: true });

        try {
            e.target.setPointerCapture && e.target.setPointerCapture(e.pointerId);
        } catch (_) { }
    }

    function startDrag(e) {
        startTracker(e, function (dx, dy) {
            send('drag:' + dx + ':' + dy);
        }, { guardInteractive: true });
    }

    function startResize(edge, e) {
        e.stopPropagation();
        startTracker(e, function (dx, dy) {
            send('resize:' + edge + ':' + dx + ':' + dy);
        });
        e.preventDefault();
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
