const root = document.getElementById("main");
const app = Elm.Main.init({ node: root, flags: {} });
const ports = app.ports;
const invoke = window.__TAURI__.invoke;
const { listen } = window.__TAURI__.event;
const { type } = window.__TAURI__.os;

ports.svn.subscribe(async (path) => {
  ports.updateStatus.send(
    await invoke("svn_status", {
      path: path,
    }),
  );
});

ports.checkout.subscribe(async (args) => {
  args["os"] = await type();
  ports.updateStatus.send(await invoke("svn_checkout", args));
});

ports.commit.subscribe(async (args) => {
  args["os"] = await type();
  ports.updateStatus.send(await invoke("svn_commit", args));
});

ports.revert.subscribe(async (args) => {
  ports.updateStatus.send(await invoke("svn_revert", args));
});

ports.setPath.subscribe(async () => {
  await invoke("set_path", {});
});

await listen("path_change", (event) => {
  ports.updatePath.send(event.payload.path);
  ports.updateRepo.send(event.payload.repo);
});
