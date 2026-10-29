#!/bin/sh

# 定義固定路徑
BIN_DIR="$HOME/.geniuz/bin"
LIB_DIR="$HOME/.geniuz/lib"
BIN_EXEC="$BIN_DIR/geniuz.bin"

# 檢查執行檔是否存在且可執行
if [ ! -x "$BIN_EXEC" ]; then
    echo "錯誤：找不到可執行檔 $BIN_EXEC" >&2
    exit 1
fi

# 設定 LD_LIBRARY_PATH
# 如果原本已有設定，則追加；若無，則直接設定
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
    export LD_LIBRARY_PATH="$LIB_DIR:$LD_LIBRARY_PATH"
else
    export LD_LIBRARY_PATH="$LIB_DIR"
fi

# 執行程式並傳入所有參數
exec "$BIN_EXEC" "$@"
