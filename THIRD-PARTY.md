# 同梱する第三者製ソフトウェア

| ファイル | 配布条件と出典 |
| --- | --- |
| `payload/ddraw.dll` | DDrawCompat 0.7.2 のリリースバイナリ。BSD Zero Clause License（0BSD）。[公式リリース](https://github.com/narzoul/DDrawCompat/releases/tag/v0.7.2) · [ライセンス本文](licenses/DDrawCompat.txt) |
| `vendor/_inmm238.zip` | _inmm.dll 2.38 の配布元アーカイブ。作者はファイルの内容を変更しない形での再配布を許可しています。同梱の ZIP は配布時のままで、インストーラーは DLL と `_inmmserv.exe` を展開します。[公式マニュアルの配布条件](https://cryo.jp/_inmm/manual_s7.php) · [配布元 ZIP](https://cryo.jp/_inmm/_inmm/_inmm238.zip) |

`payload/HG2JP.dll` はこのパッチ用にビルドした DLL です。ソースは `source/HG2JP.c` にあります。
