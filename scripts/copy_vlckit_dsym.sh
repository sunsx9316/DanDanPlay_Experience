#!/bin/bash
# 将 VLCKit dSYM 复制到 Archive 中，解决 App Store 上传缺少 dSYM 的问题
# dSYM 文件位于 Share/VLCFramework/dSYMs/<platform>/

set -e

if [ "${ACTION}" != "install" ]; then
    echo "[VLCFramework dSYM] 跳过：非 Archive 构建"
    exit 0
fi

echo "[VLCFramework dSYM] Archive 构建，平台: ${PLATFORM_NAME}"

DSYM_SRC="${PROJECT_DIR}/../Share/VLCFramework/dSYMs/${PLATFORM_NAME}/VLCKit.framework.dSYM"

if [ ! -d "${DSYM_SRC}" ]; then
    echo "[VLCFramework dSYM] 错误: dSYM 未找到于 ${DSYM_SRC}"
    exit 1
fi

echo "[VLCFramework dSYM] 源: ${DSYM_SRC}"
echo "[VLCFramework dSYM] 目标: ${DWARF_DSYM_FOLDER_PATH}/"

cp -R "${DSYM_SRC}" "${DWARF_DSYM_FOLDER_PATH}/"

echo "[VLCFramework dSYM] 复制成功"
