const root = document.getElementById("main");
const app = Elm.Main.init({ node: root, flags: {} });
const ports = app.ports;
const invoke = window.__TAURI__.invoke;
const { listen } = window.__TAURI__.event;

ports.svn.subscribe(async (path) => {
  ports.updateText.send(
    await invoke("svn", {
      path: path,
    }),
  );
});

ports.setPath.subscribe(async () => {
  await invoke("set_path", {});
});

await listen("path_change", (event) => {
  ports.updatePath.send(event.payload.msg);
});
