# Heavy Gear 2 日本語版 Windows 11 パッチ

Cyberfront 版 Heavy Gear 2 日本語版を Windows 11 x64 で動かすためのパッチです。

## 用意するもの

- Cyberfront 版 Heavy Gear 2 日本語版のゲームCD。
- 同じ日本語版の CD イメージ（`HG2JP.CUE` と `HG2JP.IMG`）。
- 日本語のシステム ロケール（コードページ932）を使用する Windows 11 x64。
- 初回のFFmpeg自動取得に使うインターネット接続。ダウンロードは約110 MiBです。
- ゲームを置くドライブの空き容量。CDから新規インストールする場合は1 GB以上、既存のゲームにパッチを適用する場合は500 MB以上です。
- FFmpegを自動取得する場合は、ユーザーの一時フォルダと `%LOCALAPPDATA%` があるドライブに合計350 MB以上の空き容量。

## インストール

パッチ一式を展開します。CUEを自動で検出させるには、`HG2JP.CUE` と `HG2JP.IMG` を展開先に置きます。`HG2JP.CUE` を仮想CDドライブにマウントします。[ImgDrive](https://www.yubsoft.com/imgdrive/)

### CDから新規インストール

1. `Install-From-CD.cmd` をダブルクリックします。CUEを求められた場合は `HG2JP.CUE` を選択してください。
2. ゲーム本体がCDのデータから展開され、Windows 11用パッチが続けて適用されます。CD内のセットアップを起動する手順は不要です。
3. `Installed successfully` と表示されたら、`%USERPROFILE%\Games\Heavy Gear 2` にある `Launch-Win11.cmd` を起動します。

インストール先を変更する場合は、コマンドプロンプトで `Install-From-CD.cmd -GameDir "D:\Games\Heavy Gear 2"` のように、書き込み可能な場所にある新規フォルダを指定します。

### CD内のインストーラーで入れたゲームにパッチを適用

1. ゲームCD内のインストーラーで、ゲーム本体をインストールしておきます。ゲームフォルダに `Heavy Gear 2.exe` と `Shell\Movies` の元の動画29本が入る構成でインストールしてください。
2. ゲームを終了し、展開先の `Install-Win11.cmd` をダブルクリックします。標準のゲームフォルダと、ゲームフォルダまたは展開先にあるCUEは自動で検出します。別の場所にある場合は、画面の案内に従って選択してください。
3. Windowsの管理者確認が表示された場合は［はい］を選びます。
4. `Installed successfully` と表示されたら、ゲームフォルダの `Launch-Win11.cmd` を起動します。

どちらの方法でも動画の変換は自動で進み、CDの音声トラック02〜19は `CDDA` フォルダに128 kbpsのMP3として保存されます。普段プレイする Windows アカウントで起動すると、初回にそのアカウント用のBGM設定が作られます。

`ffmpeg.exe` と `ffprobe.exe` がPATH上の同じフォルダにあれば、それらを使用します。自動取得したFFmpegはSHA-256で照合し、`%LOCALAPPDATA%\Cyberfront\Heavy Gear 2\Tools` に保存して次回も使います。[FFmpeg 9.0.2 Essentialsの配布元](https://github.com/GyanD/codexffmpeg/releases/tag/9.0.2)

シングルプレイ時は CD をマウントしたままにしてください。ドライブ文字は PC によって異なって構いません。

以前のWAV版から更新するときは、インストーラーを同じゲームフォルダに適用します。既存のWAVを変換し、元のWAVはインストール時のバックアップに移します。

## 修正内容

- Windows 11 用の起動処理と DDrawCompat 0.7.2
- 16bitカラーの画面モードと1600×900の解像度
- 日本語 HUD の表示とフォント、および日本語キーボード向けのキー定義
- オープニングとゲーム内動画29本の AVI 変換（Microsoft Video 1 と PCM 音声）
- _inmm.dll 2.38 によるゲーム内の進行に連動した MP3 BGM 再生

## 元に戻す場合

1. ゲームを終了します。
2. インストール完了時に表示された `Win11-transfer-backup-日時-識別子` を開きます。
3. `Original` の中身をゲームフォルダにコピーして上書きします。
4. `Added.txt` に記載されたファイルとフォルダをゲームフォルダから取り除きます。保護されたフォルダでは管理者確認が表示されます。

## 画面が出ない場合

ゲームを終了し、ゲームフォルダ内の `Shell\texts\options.cfg` を開きます。`ScreenResolutionWH` を `640 480`、`ColorDepth` を `16`、`DefaultVideoCard` を `""` にして保存します。

`Program Files (x86)` にインストールしている場合、ユーザー別の `options.cfg` が `%LOCALAPPDATA%\VirtualStore` 以下の同じ階層にあることがあります。その場合はユーザー別のファイルを変更してください。起動記録は `%LOCALAPPDATA%\Cyberfront\Heavy Gear 2\Launch-Win11.log` にあります。

第三者製ソフトウェアの配布条件は [THIRD-PARTY.md](THIRD-PARTY.md) を参照してください。
