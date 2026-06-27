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

# ---- MPVKit dSYM 生成 ----
# MPVKit framework 预编译时不含 DWARF，dsymutil 仍能生成含符号表的 dSYM
# 用于 App Store 上传的符号验证及基本的 crash symbolication

FRAMEWORKS_DIR="${CODESIGNING_FOLDER_PATH}/Frameworks"

if [ -d "${FRAMEWORKS_DIR}" ]; then
    echo "[MPVKit dSYM] 扫描: ${FRAMEWORKS_DIR}"
    GENERATED_COUNT=0

    for framework_path in "${FRAMEWORKS_DIR}"/*.framework; do
        framework_name=$(basename "${framework_path}" .framework)
        framework_binary="${framework_path}/${framework_name}"

        if [ ! -f "${framework_binary}" ]; then
            continue
        fi

        dsym_output="${DWARF_DSYM_FOLDER_PATH}/${framework_name}.framework.dSYM"

        if [ -d "${dsym_output}" ]; then
            continue
        fi

        echo "[MPVKit dSYM] ${framework_name}: 生成 dSYM..."
        xcrun dsymutil "${framework_binary}" -o "${dsym_output}" 2>/dev/null

        if [ -d "${dsym_output}" ]; then
            uuid=$(xcrun dwarfdump --uuid "${dsym_output}" 2>/dev/null | awk '{print $2}' | head -1)
            echo "[MPVKit dSYM] ${framework_name}: 完成 (UUID: ${uuid})"
            GENERATED_COUNT=$((GENERATED_COUNT + 1))
        fi
    done

    echo "[MPVKit dSYM] 完成: ${GENERATED_COUNT} 个生成"
else
    echo "[MPVKit dSYM] 跳过: Frameworks 目录不存在"
fi
