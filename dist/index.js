const root = document.getElementById("main");
const app = Elm.Main.init({ node: root, flags: {} });
const ports = app.ports;
const invoke = window.__TAURI__.invoke;

ports.svn.subscribe(async () => {
  ports.updateText.send(await invoke("svn", {}));
});
