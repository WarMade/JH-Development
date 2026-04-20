let hudVisible = false;

function setMode(newMode) {
    fetch(`https://${GetParentResourceName()}/changeMode`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode: newMode })
    });
}

function closeMenu() {
    fetch(`https://${GetParentResourceName()}/closeMenu`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

window.addEventListener('message', function(event) {
    let data = event.data;

    if (data.action === "toggleMenu") {
        document.getElementById('settings-menu').style.display = data.status ? "flex" : "none";
    }

    if (data.action === "updateHUD") {
        const rpmBar = document.getElementById('rpm-bar-fill');
        const wrapper = document.getElementById('hud-wrapper');
        const stallWarn = document.getElementById('stall-warning');

        let rpmPercent = (data.rpm || 0) * 100;
        rpmBar.style.width = rpmPercent + "%";

        if (data.rpm > 0.88) {
            rpmBar.classList.add('redline-active');
            rpmBar.style.backgroundColor = "#ff3b3b";
        } else {
            rpmBar.classList.remove('redline-active');

            if (data.rpm > 0.65) {
                rpmBar.style.backgroundColor = "#fbc02d";
            } else {
                rpmBar.style.backgroundColor = "#00ff8c";
            }
        }

        stallWarn.style.display = data.isStalled ? "block" : "none";
        wrapper.style.opacity = '1';
        hudVisible = true;
    }

    if (data.action === "hideHUD") {
        document.getElementById('hud-wrapper').style.opacity = '0';
        hudVisible = false;
    }
});

document.body.style.display = 'block';
