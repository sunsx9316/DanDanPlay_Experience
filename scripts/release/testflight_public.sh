#!/usr/bin/env bash
set -euo pipefail

# TestFlight 外部测试自动分发
#
# 用法:
#   ASC_KEY_ID=xxx ASC_ISSUER_ID=yyy \
#     ./scripts/release/testflight_public.sh 2026111901 \
#     --whats-new-file /tmp/release_changelog_ios.txt
#
# 环境变量:
#   ASC_KEY_ID        App Store Connect API Key ID（必填）
#   ASC_ISSUER_ID     App Store Connect Issuer ID（必填）
#   ASC_KEY_PATH      .p8 路径，默认 ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
#   BUNDLE_ID         默认 com.anixplayer.ios
#   TESTFLIGHT_GROUP  外部测试组名称，默认 public
#   WATCH_TIMEOUT     等待审核的最长秒数，默认 259200（72 小时）
#   POLL_INTERVAL     轮询间隔秒数，默认 300（5 分钟）
#
# 流程:
#   1. 等构建处理完成（processingState=VALID）
#   2. 写入 What to Test（whatsNew）
#   3. 把构建加入外部测试组
#   4. 提交 Beta App Review
#   5. 轮询审核状态，APPROVED 后确认构建已分发给测试组

BUILD="${1:-}"
if [ -z "$BUILD" ] || [[ "$BUILD" == --* ]]; then
    echo "用法: ASC_KEY_ID=... ASC_ISSUER_ID=... $0 <build> [--submit-only] [--whats-new <text>] [--whats-new-file <path>]" >&2
    exit 2
fi
shift

SUBMIT_ONLY=0
WHATS_NEW=""
WHATS_NEW_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --submit-only)
            SUBMIT_ONLY=1
            shift
            ;;
        --whats-new)
            WHATS_NEW="${2:-}"
            shift 2
            ;;
        --whats-new-file)
            WHATS_NEW_FILE="${2:-}"
            shift 2
            ;;
        *)
            echo "未知参数: $1" >&2
            exit 2
            ;;
    esac
done

if [ -n "$WHATS_NEW_FILE" ]; then
    [ -f "$WHATS_NEW_FILE" ] || { echo "找不到更新日志: $WHATS_NEW_FILE" >&2; exit 2; }
    WHATS_NEW="$(cat "$WHATS_NEW_FILE")"
fi

BUNDLE_ID="${BUNDLE_ID:-com.anixplayer.ios}"
GROUP_NAME="${TESTFLIGHT_GROUP:-public}"
WATCH_TIMEOUT="${WATCH_TIMEOUT:-259200}"
POLL_INTERVAL="${POLL_INTERVAL:-300}"

: "${ASC_KEY_ID:?请设置 ASC_KEY_ID（App Store Connect API Key ID）}"
: "${ASC_ISSUER_ID:?请设置 ASC_ISSUER_ID（App Store Connect Issuer ID）}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"

[ -f "$ASC_KEY_PATH" ] || {
    echo "找不到 API Key 文件: $ASC_KEY_PATH" >&2
    echo "请在 App Store Connect → 用户和访问 → 集成 → App Store Connect API 创建 Team Key，并放到上述路径。" >&2
    exit 2
}

for cmd in curl jq node; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "缺少依赖: $cmd" >&2; exit 2; }
done

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

make_token() {
    ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER_ID" ASC_KEY_PATH="$ASC_KEY_PATH" node <<'NODE'
const crypto = require('crypto');
const fs = require('fs');

const keyId = process.env.ASC_KEY_ID;
const issuerId = process.env.ASC_ISSUER_ID;
const keyPath = process.env.ASC_KEY_PATH;
const now = Math.floor(Date.now() / 1000);

const b64url = (obj) => Buffer.from(JSON.stringify(obj))
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');

const header = b64url({ alg: 'ES256', kid: keyId, typ: 'JWT' });
const payload = b64url({ iss: issuerId, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' });
const input = `${header}.${payload}`;
const signature = crypto.sign('sha256', Buffer.from(input), {
    key: fs.readFileSync(keyPath),
    dsaEncoding: 'ieee-p1363'
});
process.stdout.write(`${input}.${signature.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')}`);
NODE
}

TOKEN=""
TOKEN_AT=0
API_CODE=""
API_BODY=""

refresh_token() {
    TOKEN="$(make_token)"
    TOKEN_AT="$(date +%s)"
}

api() {
    local method="$1"
    local path="$2"
    local body="${3:-}"

    if [ -z "$TOKEN" ] || [ $(( $(date +%s) - TOKEN_AT )) -gt 540 ]; then
        refresh_token
    fi

    local tmp
    tmp="$(mktemp)"
    local args=(-sS --globoff -X "$method"
        -H "Authorization: Bearer $TOKEN"
        -H "Accept: application/json"
        -o "$tmp"
        -w '%{http_code}')

    if [ -n "$body" ]; then
        args+=(-H "Content-Type: application/json" -d "$body")
    fi

    API_CODE="$(curl "${args[@]}" "https://api.appstoreconnect.apple.com$path")" || {
        rm -f "$tmp"
        echo "网络请求失败: $method $path" >&2
        exit 1
    }
    API_BODY="$(cat "$tmp")"
    rm -f "$tmp"
}

require_2xx() {
    case "$API_CODE" in
        2*) ;;
        *)
            echo "API 请求失败 ($API_CODE)" >&2
            echo "$API_BODY" >&2
            exit 1
            ;;
    esac
}

log "解析 App（${BUNDLE_ID}）"
api GET "/v1/apps?filter[bundleId]=$BUNDLE_ID&limit=1"
require_2xx
APP_ID="$(jq -r '.data[0].id // empty' <<<"$API_BODY")"
[ -n "$APP_ID" ] || { echo "找不到 App: $BUNDLE_ID" >&2; exit 1; }

log "等待构建 $BUILD 处理完成"
BUILD_ID=""
while :; do
    api GET "/v1/builds?filter[app]=$APP_ID&filter[version]=$BUILD&sort=-uploadedDate&limit=1"
    require_2xx

    BUILD_ID="$(jq -r '.data[0].id // empty' <<<"$API_BODY")"
    STATE="$(jq -r '.data[0].attributes.processingState // empty' <<<"$API_BODY")"

    if [ -z "$BUILD_ID" ]; then
        log "未找到构建，${POLL_INTERVAL}s 后重试"
    elif [ "$STATE" = "VALID" ]; then
        log "构建已就绪: $BUILD_ID"
        break
    elif [ "$STATE" = "FAILED" ] || [ "$STATE" = "INVALID" ]; then
        echo "构建处理失败: $STATE" >&2
        exit 1
    else
        log "构建状态: $STATE，${POLL_INTERVAL}s 后重试"
    fi

    sleep "$POLL_INTERVAL"
done

log "查找外部测试组: $GROUP_NAME"
api GET "/v1/betaGroups?filter[app]=$APP_ID&limit=200"
require_2xx
GROUP_ID="$(jq -r --arg name "$GROUP_NAME" '.data[] | select((.attributes.name | ascii_downcase) == ($name | ascii_downcase)) | .id' <<<"$API_BODY" | head -1)"
[ -n "$GROUP_ID" ] || {
    echo "找不到测试组: $GROUP_NAME" >&2
    echo "现有测试组:" >&2
    jq -r '.data[] | "- \(.attributes.name)\(if .attributes.isInternalGroup then "（内部）" else "（外部）" end)"' <<<"$API_BODY" >&2
    exit 1
}

if [ -n "$WHATS_NEW" ]; then
    log "写入 What to Test"
    api GET "/v1/builds/$BUILD_ID/betaBuildLocalizations"
    require_2xx
    while IFS= read -r loc_id; do
        [ -n "$loc_id" ] || continue
        api PATCH "/v1/betaBuildLocalizations/$loc_id" \
            "$(jq -n --arg id "$loc_id" --arg text "$WHATS_NEW" '{data:{type:"betaBuildLocalizations",id:$id,attributes:{whatsNew:$text}}}')"
        require_2xx
    done < <(jq -r '.data[].id' <<<"$API_BODY")
fi

log "把构建加入测试组: $GROUP_NAME"
api POST "/v1/betaGroups/$GROUP_ID/relationships/builds" \
    "$(jq -n --arg id "$BUILD_ID" '{data:[{type:"builds",id:$id}]}')"
case "$API_CODE" in
    2*) ;;
    409) log "构建已在测试组中" ;;
    *)
        echo "加入测试组失败 ($API_CODE)" >&2
        echo "$API_BODY" >&2
        exit 1
        ;;
esac

log "检查 Beta App Review"
api GET "/v1/builds/$BUILD_ID/betaAppReviewSubmission"
case "$API_CODE" in
    200)
        REVIEW_STATE="$(jq -r '.data.attributes.betaReviewState // empty' <<<"$API_BODY")"
        log "已有审核记录: ${REVIEW_STATE:-未知}"
        ;;
    404)
        log "提交 Beta App Review"
        api POST "/v1/betaAppReviewSubmissions" \
            "$(jq -n --arg id "$BUILD_ID" '{data:{type:"betaAppReviewSubmissions",relationships:{build:{data:{type:"builds",id:$id}}}}}')"
        case "$API_CODE" in
            2*) ;;
            409) log "审核提交已存在" ;;
            *)
                echo "提交审核失败 ($API_CODE)" >&2
                echo "$API_BODY" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        echo "查询审核状态失败 ($API_CODE)" >&2
        echo "$API_BODY" >&2
        exit 1
        ;;
esac

if [ "$SUBMIT_ONLY" = "1" ]; then
    log "已提交，按 --submit-only 退出"
    exit 0
fi

DEADLINE=$(( $(date +%s) + WATCH_TIMEOUT ))
log "等待审核结果（最长 ${WATCH_TIMEOUT}s）"
while :; do
    api GET "/v1/builds/$BUILD_ID/betaAppReviewSubmission"
    require_2xx
    REVIEW_STATE="$(jq -r '.data.attributes.betaReviewState // empty' <<<"$API_BODY")"
    log "审核状态: ${REVIEW_STATE:-未知}"

    case "$REVIEW_STATE" in
        APPROVED)
            log "审核通过，确认构建已分发给 $GROUP_NAME"
            api POST "/v1/betaGroups/$GROUP_ID/relationships/builds" \
                "$(jq -n --arg id "$BUILD_ID" '{data:[{type:"builds",id:$id}]}')"
            case "$API_CODE" in
                2*|409) ;;
                *)
                    echo "分发确认失败 ($API_CODE)" >&2
                    echo "$API_BODY" >&2
                    exit 1
                    ;;
            esac
            log "完成: $BUILD 已发布到 TestFlight 外部测试组 $GROUP_NAME"
            exit 0
            ;;
        REJECTED)
            echo "Beta App Review 被拒绝，请在 App Store Connect 查看原因。" >&2
            exit 1
            ;;
    esac

    if [ "$(date +%s)" -ge "$DEADLINE" ]; then
        echo "等待审核超时（${WATCH_TIMEOUT}s），可重新运行本脚本继续等待。" >&2
        exit 1
    fi

    sleep "$POLL_INTERVAL"
done
