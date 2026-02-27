/* bg-video.js — FreshTomato Video Background Injector
   - Video background via bgmp4.gif
   - Mute/unmute + hide/show panels
   - "Click to unmute" hint saat refresh dengan audio ON
   - Controls muncul saat kursor dekat (80px)
*/
(function () {

    var vidStyle=document.createElement('style');
    vidStyle.textContent='#bg-video{position:fixed;top:0;left:0;width:100vw;height:100vh;z-index:-1;object-fit:cover;object-position:center center;pointer-events:none;}';
    document.head.appendChild(vidStyle);

    var vid=document.createElement('video');
    vid.id='bg-video'; vid.autoplay=vid.loop=vid.muted=vid.playsInline=true;
    vid.setAttribute('playsinline','');
    var src=document.createElement('source');
    src.src='/bgmp4.gif'; src.type='video/mp4';
    vid.appendChild(src);

    // ── AUTOPLAY + AUDIO UNLOCK ────────────────────────────
    function unlockAndPlay(){
        var wasUnmuted = localStorage.getItem('ft_bg_muted') === 'false';
        vid.muted = true;
        vid.play().catch(function(){
            var ev=['click','touchstart','keydown'];
            function onGesture(){
                ev.forEach(function(e){document.removeEventListener(e,onGesture);});
                vid.play().catch(function(){});
            }
            ev.forEach(function(e){document.addEventListener(e,onGesture,{once:true});});
        });
        if(wasUnmuted) showTapHint();
    }

    function showTapHint(){
        if(document.getElementById('ft-tap-hint')) return;
        var hStyle=document.createElement('style');
        hStyle.textContent=
            '#ft-tap-hint{position:fixed;bottom:62px;right:16px;z-index:9998;'+
            'background:rgba(15,15,15,0.7);backdrop-filter:blur(8px);'+
            '-webkit-backdrop-filter:blur(8px);color:#fff;font-size:12px;'+
            'padding:6px 12px;border-radius:20px;cursor:pointer;'+
            'box-shadow:0 2px 8px rgba(0,0,0,0.4);'+
            'display:flex;align-items:center;gap:6px;'+
            'animation:ft-pulse 1.5s ease-in-out infinite;}'+
            '@keyframes ft-pulse{0%,100%{opacity:0.7;}50%{opacity:1;}}';
        document.head.appendChild(hStyle);
        var hint=document.createElement('div');
        hint.id='ft-tap-hint';
        hint.innerHTML=
            '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'+
            '<path d="M11 5L6 9H2v6h4l5 4V5z"/>'+
            '<path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>'+
            '<path d="M19.07 4.93a10 10 0 0 1 0 14.14"/></svg>'+
            '<span>Click to unmute</span>';
        function removeHint(){
            if(hint.parentNode) hint.parentNode.removeChild(hint);
            if(hStyle.parentNode) hStyle.parentNode.removeChild(hStyle);
        }
        hint.addEventListener('click',function(){
            vid.muted=false;
            localStorage.setItem('ft_bg_muted','false');
            // Sync icon tombol mute jika controls sudah ada
            var btn=document.getElementById('ft-btn-mute');
            if(btn){isMuted=false;btn.innerHTML=icons.unmuted;btn.title='Mute';}
            removeHint();
        });
        function attach(){
            document.body.appendChild(hint);
            setTimeout(removeHint,8000);
        }
        if(document.body) attach();
        else document.addEventListener('DOMContentLoaded',attach);
    }

    function insertVideo(){
        if(document.body){
            document.body.insertBefore(vid,document.body.firstChild);
            unlockAndPlay();
        } else {
            document.addEventListener('DOMContentLoaded',function(){
                document.body.insertBefore(vid,document.body.firstChild);
                unlockAndPlay();
            });
        }
    }
    insertVideo();

    // ── CONTROLS ───────────────────────────────────────────
    var MUTE_KEY='ft_bg_muted';
    var PANEL_KEY='ft_panel_hidden';
    var TRIGGER_RADIUS=80;
    var isMuted      =localStorage.getItem(MUTE_KEY) ===null?true :localStorage.getItem(MUTE_KEY) ==='true';
    var isPanelHidden=localStorage.getItem(PANEL_KEY)===null?false:localStorage.getItem(PANEL_KEY)==='true';

    var cStyle=document.createElement('style');
    cStyle.textContent=[
        '#ft-controls{position:fixed;bottom:16px;right:16px;z-index:9999;display:flex;gap:8px;opacity:0;transform:translateY(6px);transition:opacity 0.25s ease,transform 0.25s ease;pointer-events:none;}',
        '#ft-controls.visible{opacity:1;transform:translateY(0);pointer-events:auto;}',
        '#ft-controls button{width:34px;height:34px;border-radius:50%;border:none;background:rgba(15,15,15,0.6);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);color:#fff;cursor:pointer;display:flex;align-items:center;justify-content:center;padding:0;transition:background 0.2s,transform 0.15s;box-shadow:0 2px 8px rgba(0,0,0,0.4);}',
        '#ft-controls button:hover{background:rgba(40,40,40,0.85);transform:scale(1.1);}',
        '#ft-controls button svg{width:16px;height:16px;fill:none;stroke:#fff;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;}',
        'body.ft-panel-hidden #container,body.ft-panel-hidden #navi,body.ft-panel-hidden #footer{opacity:0!important;pointer-events:none!important;transition:opacity 0.3s ease;}',
        'body:not(.ft-panel-hidden) #container,body:not(.ft-panel-hidden) #navi,body:not(.ft-panel-hidden) #footer{opacity:1;transition:opacity 0.3s ease;}'
    ].join('');
    document.head.appendChild(cStyle);

    var icons={
        muted:  '<svg viewBox="0 0 24 24"><path d="M11 5L6 9H2v6h4l5 4V5z"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/></svg>',
        unmuted:'<svg viewBox="0 0 24 24"><path d="M11 5L6 9H2v6h4l5 4V5z"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/></svg>',
        hide:   '<svg viewBox="0 0 24 24"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>',
        show:   '<svg viewBox="0 0 24 24"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>'
    };

    var controls=document.createElement('div');
    controls.id='ft-controls';

    var btnPanel=document.createElement('button');
    function applyPanel(hidden){
        isPanelHidden=hidden;
        localStorage.setItem(PANEL_KEY,hidden?'true':'false');
        btnPanel.innerHTML=hidden?icons.show:icons.hide;
        btnPanel.title=hidden?'Show panels':'Hide panels';
        hidden?document.body.classList.add('ft-panel-hidden'):document.body.classList.remove('ft-panel-hidden');
    }
    btnPanel.addEventListener('click',function(){applyPanel(!isPanelHidden);});

    var btnMute=document.createElement('button');
    btnMute.id='ft-btn-mute';
    function applyMute(muted){
        isMuted=muted; vid.muted=muted;
        localStorage.setItem(MUTE_KEY,muted?'true':'false');
        btnMute.innerHTML=muted?icons.muted:icons.unmuted;
        btnMute.title=muted?'Unmute':'Mute';
        var hint=document.getElementById('ft-tap-hint');
        if(hint&&hint.parentNode)hint.parentNode.removeChild(hint);
    }
    btnMute.addEventListener('click',function(){applyMute(!isMuted);});

    controls.appendChild(btnPanel);
    controls.appendChild(btnMute);

    function attachControls(){
        document.body.appendChild(controls);
        vid.addEventListener('canplay',function(){applyMute(isMuted);});
        applyMute(isMuted);
        applyPanel(isPanelHidden);
        document.addEventListener('mousemove',function(e){
            var rect=controls.getBoundingClientRect();
            var cx=rect.left+rect.width/2, cy=rect.top+rect.height/2;
            var dist=Math.sqrt(Math.pow(e.clientX-cx,2)+Math.pow(e.clientY-cy,2));
            dist<TRIGGER_RADIUS?controls.classList.add('visible'):controls.classList.remove('visible');
        });
    }
    if(document.body) attachControls();
    else document.addEventListener('DOMContentLoaded',attachControls);

})();
