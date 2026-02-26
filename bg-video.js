/* bg-video.js — FreshTomato Video Background Injector
   - Video background via bgmp4.gif
   - Mute/unmute button (state persisted via localStorage)
   - Hide/show panels button (state persisted via localStorage)
   - Controls auto-hide when cursor moves away
*/
(function () {
    var MUTE_KEY  = 'ft_bg_muted';
    var PANEL_KEY = 'ft_panel_hidden';

    // ── VIDEO ──────────────────────────────────────────────
    var vid = document.createElement('video');
    vid.id = 'bg-video';
    vid.autoplay    = true;
    vid.loop        = true;
    vid.muted       = true;
    vid.playsInline = true;
    vid.setAttribute('playsinline', '');
    var src = document.createElement('source');
    src.src  = '/bgmp4.gif';
    src.type = 'video/mp4';
    vid.appendChild(src);
    document.body.insertBefore(vid, document.body.firstChild);

    // ── STATE ──────────────────────────────────────────────
    var isMuted       = localStorage.getItem(MUTE_KEY)  === null ? true  : localStorage.getItem(MUTE_KEY)  === 'true';
    var isPanelHidden = localStorage.getItem(PANEL_KEY) === null ? false : localStorage.getItem(PANEL_KEY) === 'true';

    // ── INJECT STYLE ───────────────────────────────────────
    var style = document.createElement('style');
    style.textContent = [
        '#ft-controls {',
        '  position:fixed;',
        '  bottom:16px;',
        '  right:16px;',
        '  z-index:9999;',
        '  display:flex;',
        '  gap:6px;',
        '  opacity:0;',
        '  transition:opacity 0.3s ease;',
        '  pointer-events:none;',
        '}',
        '#ft-controls.visible {',
        '  opacity:1;',
        '  pointer-events:auto;',
        '}',
        '#ft-controls button {',
        '  background:rgba(0,0,0,0.5);',
        '  color:#fff;',
        '  border:1px solid rgba(255,255,255,0.3);',
        '  border-radius:50%;',
        '  width:36px;',
        '  height:36px;',
        '  font-size:15px;',
        '  cursor:pointer;',
        '  padding:0;',
        '  line-height:36px;',
        '  text-align:center;',
        '  transition:background 0.2s;',
        '}',
        '#ft-controls button:hover {',
        '  background:rgba(0,0,0,0.75);',
        '}',
        /* Panel hidden state */
        'body.ft-panel-hidden #container,',
        'body.ft-panel-hidden #navi,',
        'body.ft-panel-hidden #footer {',
        '  opacity:0;',
        '  pointer-events:none;',
        '  transition:opacity 0.3s ease;',
        '}',
        'body:not(.ft-panel-hidden) #container,',
        'body:not(.ft-panel-hidden) #navi,',
        'body:not(.ft-panel-hidden) #footer {',
        '  opacity:1;',
        '  transition:opacity 0.3s ease;',
        '}'
    ].join('\n');
    document.head.appendChild(style);

    // ── CONTROLS WRAPPER ───────────────────────────────────
    var controls = document.createElement('div');
    controls.id = 'ft-controls';

    // ── PANEL TOGGLE BUTTON ────────────────────────────────
    var btnPanel = document.createElement('button');

    function applyPanel(hidden) {
        isPanelHidden = hidden;
        localStorage.setItem(PANEL_KEY, hidden ? 'true' : 'false');
        if (hidden) {
            document.body.classList.add('ft-panel-hidden');
            btnPanel.innerHTML = '👁';
            btnPanel.title = 'Show panels';
        } else {
            document.body.classList.remove('ft-panel-hidden');
            btnPanel.innerHTML = '🙈';
            btnPanel.title = 'Hide panels';
        }
    }

    btnPanel.addEventListener('click', function () { applyPanel(!isPanelHidden); });

    // ── MUTE TOGGLE BUTTON ─────────────────────────────────
    var btnMute = document.createElement('button');

    function applyMute(muted) {
        isMuted = muted;
        vid.muted = muted;
        localStorage.setItem(MUTE_KEY, muted ? 'true' : 'false');
        btnMute.innerHTML = muted ? '🔇' : '🔊';
        btnMute.title = muted ? 'Click to unmute' : 'Click to mute';
    }

    btnMute.addEventListener('click', function () { applyMute(!isMuted); });

    // ── ASSEMBLE ───────────────────────────────────────────
    controls.appendChild(btnPanel);
    controls.appendChild(btnMute);
    document.body.appendChild(controls);

    // ── APPLY SAVED STATE ──────────────────────────────────
    vid.addEventListener('canplay', function () { applyMute(isMuted); });
    applyMute(isMuted);
    applyPanel(isPanelHidden);

    // ── AUTO HIDE / SHOW ON CURSOR ─────────────────────────
    var hideTimer = null;

    function showControls() {
        controls.classList.add('visible');
        clearTimeout(hideTimer);
        hideTimer = setTimeout(function () {
            controls.classList.remove('visible');
        }, 2000); // sembunyikan 2 detik setelah kursor berhenti
    }

    document.addEventListener('mousemove', showControls);

    // Tetap tampil saat kursor di atas controls
    controls.addEventListener('mouseenter', function () {
        clearTimeout(hideTimer);
        controls.classList.add('visible');
    });
    controls.addEventListener('mouseleave', function () {
        hideTimer = setTimeout(function () {
            controls.classList.remove('visible');
        }, 2000);
    });
})();
