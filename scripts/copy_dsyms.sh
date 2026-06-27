#!/bin/bash
# 将缺失的 framework dSYM 复制/生成到 Archive 中，解决 App Store 上传缺少 dSYM 的问题
#
# 处理两类 framework：
# 1. VLCKit — 从本地 vendored dSYM 复制
# 2. MPVKit (Libav*, Libmpv 等) — 用 dsymutil 从 dylib 生成 dSYM（原始二进制无 DWARF，但含符号表）

if [ "${ACTION}" != "install" ]; then
    echo "[Copy dSYMs] 跳过：非 Archive 构建"
    exit 0
fi

echo "[Copy dSYMs] Archive 构建，平台: ${PLATFORM_NAME}"

# ========================
# VLCKit: 复制 vendored dSYM
# ========================
VLCDSYM_SRC="${PROJECT_DIR}/../Share/VLCFramework/dSYMs/${PLATFORM_NAME}/VLCKit.framework.dSYM"

if [ -d "${VLCDSYM_SRC}" ]; then
    echo "[VLCKit] 复制: ${VLCDSYM_SRC} → ${DWARF_DSYM_FOLDER_PATH}/"
    cp -R "${VLCDSYM_SRC}" "${DWARF_DSYM_FOLDER_PATH}/"
    echo "[VLCKit] 复制成功"
else
    echo "[VLCKit] 跳过: dSYM 未找到于 ${VLCDSYM_SRC}"
    echo "[VLCKit] 提示: 此平台可能不使用 VLCKit"
fi

# ========================
# MPVKit: dsymutil 生成 dSYM
# ========================
FRAMEWORKS_DIR="${CODESIGNING_FOLDER_PATH}/Frameworks"

if [ ! -d "${FRAMEWORKS_DIR}" ]; then
    echo "[MPVKit] 跳过: Frameworks 目录不存在"
    exit 0
fi

echo "[MPVKit] 扫描: ${FRAMEWORKS_DIR}"
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

    echo "[MPVKit] ${framework_name}: 生成 dSYM..."
    xcrun dsymutil "${framework_binary}" -o "${dsym_output}" 2>/dev/null

    if [ -d "${dsym_output}" ]; then
        uuid=$(xcrun dwarfdump --uuid "${dsym_output}" 2>/dev/null | awk '{print $2}' | head -1)
        echo "[MPVKit] ${framework_name}: 完成 (UUID: ${uuid})"
        GENERATED_COUNT=$((GENERATED_COUNT + 1))
    else
        echo "[MPVKit] ${framework_name}: 失败"
    fi
done

echo "[Copy dSYMs] 完成: VLCKit 已复制, MPVKit ${GENERATED_COUNT} 个生成"
