#! /usr/bin/env bash

#
#     beaver build script
#
#     (c)2020-2021 naiad technology
#
#     build.sh
#

# set -e

function _msg_error(){ echo "[ERROR] ${*}" >&2; }
function _msg_info (){ echo "[INFO] ${*}" >&1; }

function chk-command () {
    local chk_command="${1}"
    echo -n "[INFO] checking $chk_command"
    if type "${chk_command}" > /dev/null 2>&1; then
      echo ">>> ok"
    else
      echo ">>> not found!"
      _msg_error "${chk_command} が使用できないため続行できません。中止します。"
      exit 1
    fi
}

# オプション解析
opts=("t:" "l:" "d" "v:") optl=("target:" "lang:" "docker" "version:")
getopt=(-o "$(printf "%s," "${opts[@]}")" -l "$(printf "%s," "${optl[@]}")" -- "${@}")
getopt -Q "${getopt[@]}" || exit 1 # 引数エラー判定
readarray -t opt < <(getopt "${getopt[@]}") # 配列に代入
eval set -- "${opt[@]}" # 引数に設定
unset opts optl getopt opt # 使用した配列を削除

while true; do
  case "${1}" in
    "-t" | "--target" ) target="${2}"       && shift 2 ;;
    "-l" | "--lang"   ) over_locale="${2}"  && shift 2 ;;
    "-d" | "--docker" ) docker_build=true   && shift 1 ;;
    "-v" | "--version") over_version="${2}" && shift 2 ;;
    "--"              ) shift 1             && break   ;;
    *) 
        echo "Unexpected error"
        exit 1
        ;;
  esac
done
#target="${1-""}"

# カレントディレクトリ取得
current_dir="$(cd "$(dirname "${0}")" && pwd)"

# sudo生存確認
chk-command sudo

# Dockerを使うかどうか
if [ "${docker_build}" = true ]; then

    _msg_info "ビルドにDockerを利用します。"
    docker_build=true
    chk-command docker

    if [ -z "$(sudo docker container ls -q -a -f name="beaver_build")" ]; then
        docker_ready=false
    else
        docker_ready=true
    fi

else
    _msg_info "ローカル環境でビルドします。"
    docker_build=false
    chk-command kiwi-ng
fi

# カレントディレクトリが取得できてるか（事故防止）
if [[ -z "${current_dir}" ]]; then
    _msg_error "カレントディレクトリの取得に失敗しました。開発者に以下のコードとコマンドラインの出力を送信してください。"
    _msg_error "(CriticalError: InvalidValue: current_dir=\"${current_dir}\")"
    exit 1
fi

# 引数をチェック
[[ -z "${target}" ]] && echo "ターゲットを指定してください" >&2 && exit 1

# プロファイルをチェック
if [ -d "${target}" ]; then
    _msg_info "ディレクトリ ${target} を使用します"
    target="$(realpath "${target}")"
    cd "${target}" || exit 1
else
    _msg_error "指定したプロファイル（\"$target\"）が存在しません。中止します。"
    exit 1
fi

_msg_info "プロファイルに必要なファイルを確認しています"

if [ -f "${target}/base.conf" ] && [ -f "${target}/main.packages" ] && [ -f "${target}/bootstrap.packages" ]; then
   _msg_info "必要なファイルの存在を確認しました"
else
   _msg_error "プロファイルに必要なファイルが存在しません。中止します。"
   exit 1
fi


# 設定読み込み
_msg_info "base.confを読み込んでいます..."
source "${target}/base.conf"

# 引数が指定されている場合、値を上書き
locale="${over_locale-"${locale}"}"
version="${over_version-"${version}"}"


# ローカライズ確認
if [ -d "${target}/I18n/${locale}" ]; then
    _msg_info "ローカライズ設定に ${locale} を使用します"
else
    _msg_error  "ローカライズファイルのディレクトリ（I18n/${locale}）が見つかりません。中止します。"
    exit 1
fi

if [ -f "${target}/I18n/${locale}/locale.conf" ]; then
   _msg_info "ローカライズの設定ファイルに ${locale}/locale.conf を使用します。"
else
   _msg_error "ローカライズ設定ファイル（I18n/$locale/locale.conf）が存在しません。中止します。"
   exit 1
fi

# ローカライズ設定読み込み
source "${target}/I18n/$locale/locale.conf"

# 一時ディレクトリ作成
cd "${current_dir}" || exit 1
_msg_info "一時ディレクトリを作成します。"
sudo rm -rf  tmp out
mkdir -p out tmp/kiwi tmp/config

# 上書きファイルへのシンボリックリンクを貼る
_msg_info "プロファイルからkiwi-ng向けの設定ファイルを生成しています。"
mkdir tmp/config/root

cp -r "${target}/root" "tmp/config/"
cp -r "${target}/I18n/${locale}/root" "tmp/config/"
cp "${target}/final_process.sh" "tmp/config/"
mv "tmp/config/final_process.sh" "tmp/config/config.sh"


# パッケージの数をカウント
packages_main_counts="$(sed '/^#/d' "${target}/main.packages" | wc -l)"
packages_bootstrap_counts="$(sed '/^#/d' "${target}/bootstrap.packages" | wc -l)"
packages_locale_counts="$(sed '/^#/d' "${target}/I18n/${locale}/locale.packages" | wc -l)"

# コメントを除去したパッケージリストを作成
mkdir tmp/beaver

touch tmp/beaver/main.packages.tmp
sed '/^#/d' "${target}/main.packages" > tmp/beaver/main.packages.tmp

touch tmp/beaver/bootstrap.packages.tmp
sed '/^#/d' "${target}/bootstrap.packages" > tmp/beaver/bootstrap.packages.tmp

touch tmp/beaver/bootstrap.packages.tmp
sed '/^#/d' "${target}/I18n/${locale}/locale.packages "> tmp/beaver/locale.packages.tmp


# xmlファイル生成
touch tmp/config/config.xml

_msg_info "config.xmlを生成します"

# xml生成処理
cat <<EOF >  tmp/config/config.xml
<?xml version="1.0" encoding="utf-8"?>

<image schemaversion="$schemaversion" name="$name">
    <description type="system">
        <author>$author</author>
        <contact>$contact</contact>
        <specification>$specification</specification>
    </description>
    <profiles>
        <profile name="DracutLive" description="Simple Live image" import="true"/>
        <profile name="Live" description="Live image"/>
        <profile name="Virtual" description="Simple Disk image"/>
        <profile name="Disk" description="Expandable Disk image"/>
    </profiles>
    <preferences>
        <version>$version</version>
        <packagemanager>$packagemanager</packagemanager>
        <locale>$locale</locale>
        <keytable>$keytable</keytable>
        <timezone>$timezone</timezone>
        <rpm-excludedocs>$rpm_xcludedocs</rpm-excludedocs>
        <rpm-check-signatures>$rpm_check_signatures</rpm-check-signatures>
        <bootsplash-theme>$bootsplash_theme</bootsplash-theme>
        <bootloader-theme>$bootloader_theme</bootloader-theme>
        <type image="$image" flags="$flags" firmware="$firmware" kernelcmdline="$kernelcmdline" hybridpersistent_filesystem="$hybridpersistent_filesystem" hybridpersistent="$hybridpersistent" mediacheck="$mediacheck">
            <bootloader name="$bootloader" console="$console" timeout="$timeout"/>
        </type>
    </preferences>
    <users>
        <user password="$root_password" pwdformat="plain" home="/root" name="root" groups="root"/>
        <user password="$liveuser_password" pwdformat="plain" home="/home/$liveuser_name" name="$liveuser_name" groups="$liveuser_name"/>
    </users>
    <repository type="$repotype">
        <source path="$url1"/>
    </repository>
EOF



# レポジトリ追記
while [[ "${repository_counts}" -gt 1 ]]; do

    url_name="url${repository_counts}"
    {
        echo "    <repository>"
        echo "        <source path=\"""${!url_name}""\"/>"
        echo "    </repository>"
    } >> tmp/config/config.xml

    repository_counts=$(( repository_counts - 1 ))

done

# テンプレを追記
echo '    <packages type="image">' >> tmp/config/config.xml



# main.packagesのパッケージを追記
packages_main_counts=$(( packages_main_counts + 1 ))
while [[ $packages_main_counts -gt 0 ]]; do
    echo "        <package name=\"$(head -n $packages_main_counts tmp/beaver/main.packages.tmp | tail -n 1)\"/>" >> tmp/config/config.xml
    packages_main_counts=$(( packages_main_counts - 1 ))
done

# ローカライズパッケージを追記
packages_locale_counts=$(( packages_locale_counts + 1 ))
while [[ $packages_locale_counts -gt 0 ]]; do
    echo "        <package name=\"$(head -n $packages_locale_counts tmp/beaver/locale.packages.tmp | tail -n 1)\"/>" >> tmp/config/config.xml
    packages_locale_counts=$(( packages_locale_counts - 1))
done


# テンプレを追記
cat <<EOF >>  tmp/config/config.xml
    </packages>
    <packages type="bootstrap">
EOF


# bootstrap.packagesのパッケージを追記
packages_bootstrap_counts=$(( packages_bootstrap_counts + 1 ))
while [[ $packages_bootstrap_counts -gt 0 ]]; do
    echo "        <package name=\"$(head -n $packages_bootstrap_counts tmp/beaver/bootstrap.packages.tmp | tail -n 1)\"/>" >> tmp/config/config.xml
    packages_bootstrap_counts=$(( packages_bootstrap_counts - 1 ))
done


# テンプレを追記
cat <<EOF >>  tmp/config/config.xml
    </packages>
</image>
EOF

# dockerを準備
if [[ "${docker_ready}" = false ]]; then
    _msg_info "Dockerのコンテナを作成します"
    sudo docker pull opensuse/tumbleweed
    sudo docker run -i -t -d --name beaver_build opensuse/tumbleweed
    sudo docker exec -i -t beaver_build zypper -n refresh
    sudo docker exec -i -t beaver_build zypper -n install python3-kiwi checkmedia util-linux
fi

# kiwi-ngでビルド
_msg_info  "kiwi-ngでのビルドを開始します"

if sudo kiwi-ng system build --description "${current_dir}/tmp/config" --target-dir "${current_dir}/out"; then
    _msg_info "Done!"
    exit 0
else
    _msg_error "kiwi-ngが終了コード0以外で終了しました。これはビルドが失敗したことを意味します。詳細なログを閲覧するには out/build/image-root.log を参照してください。"
    exit 1
fi
