# 📊 ttop - 極致輕量的 Bash 系統監控助手

![Screenshot](https://raw.githubusercontent.com/baiyuan/ttop/refs/heads/main/ttop.jpg)
> *輕量、美觀、零依賴的 Linux 系統監控方案*

**ttop** 是一款致敬 `btop` 風格的輕量級系統監控工具，完全由 **Bash Shell Script** 撰寫而成。

在不想安裝繁重套件、或是權限受限的伺服器環境中，**ttop** 是你的最佳選擇。它堅持 **零依賴 (Zero Dependency)**，僅調用 Linux 原生指令與 ANSI 色彩，就能在終端機 (Terminal) 呈現出高顏值的動態圖形化儀表板。

## 🚀 核心特色
* **免安裝、無痛執行**：複製腳本即可運作，支援幾乎所有 Linux 發行版 (Ubuntu, CentOS, Alpine, Arch...)。
* **視覺化介面**：即時顯示 CPU、RAM、磁碟 I/O 的圖形化進度條（支援負載變色警示）。
* **資訊一目了然**：整合 OS 版本、Kernel 資訊、開機時間 (Uptime) 與詳細的掛載點空間分析。
* **智慧過濾**：自動隱藏 `tmpfs`、`overlay`、`snap` 等雜亂的虛擬掛載點，只顯示真實硬碟。
* **極低資源佔用**：使用 `/proc/stat` 與 `/proc/meminfo` 讀取核心數據，比 `top` 更輕量。

## 📥 快速安裝 (Quick Start)

只要下載腳本並賦予執行權限即可：

```bash
# 下載
wget [https://github.com/你的帳號/ttop/raw/main/ttop](https://github.com/你的帳號/ttop/raw/main/ttop_gemini.sh)
# 或使用 curl
# curl -O [https://github.com/你的帳號/ttop/raw/main/ttop](https://github.com/你的帳號/ttop/raw/main/ttopgemini_.sh)

# 賦予執行權限
chmod +x ttop_gemini.sh

# 執行
./ttop_gemini.sh
