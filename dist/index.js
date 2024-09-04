const root = document.getElementById("main");
const app = Elm.Main.init({ node: root, flags: {} });
const ports = app.ports;
const invoke = window.__TAURI__.invoke;
const { listen } = window.__TAURI__.event;

ports.svn.subscribe(async (path) => {
  ports.updateStatus.send(
    await invoke("svn_status", {
      path: path,
    }),
  );
});

ports.commit.subscribe(async (args) => {
  ports.updateStatus.send(await invoke("svn_commit", args));
});

ports.svnAdd.subscribe(async (args) => {
  await invoke("svn_add", args);
});

ports.svnRemove.subscribe(async (args) => {
  await invoke("svn_remove", args);
});

ports.setPath.subscribe(async () => {
  await invoke("set_path", {});
});

await listen("path_change", (event) => {
  ports.updatePath.send(event.payload.path);
});
