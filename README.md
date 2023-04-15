# Compress [Foundry VTT](https://foundryvtt.com/) Modules
Large assets, such as background images for scenes, audio files or PDFs, can lead to long loading times on world startup, as well as for players joining the scene. At the same time, many map makers take much pride in providing you with high quality versions of their map. This small tool is designed to generate a compressed version of the high quality modules you own.

## Dependencies

This project started as a motivation to learn more about [NuShell](https://www.nushell.sh/) and is executed as a nushell script. To install nushell I recommend installing [rust with rustup](https://www.rust-lang.org/tools/install):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Afterwards you can easily install the necessary programs:

```bash
cargo install nu
cargo install sd
cargo install fd-find
cargo install ripgrep
cargo install urlencode
```

Furthermore, you will need to install googles [webp tools](https://developers.google.com/speed/webp/download), as images are compressed into the webp format:

```bash
sudo apt install webp
```