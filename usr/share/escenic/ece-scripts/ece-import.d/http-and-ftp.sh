## Common library for downloading XML feeds via FTP and HTTP.

function download_latest_files() {
  if [[ $uri == "ftp://"* ]]; then
    local user_and_password="
      $wget_opts
      --ftp-user $user
      --ftp-password $password
    "
  elif [[ $uri == "http://"* ]]; then
    local user_and_password="
      $wget_opts
      --http-user $user
      --http-password $password
    "
  fi

  # sets the global wget_opts variable, which
  # common-io::download_uri_target_to_dir respects.
  wget_opts="${user_and_password} ${wget_opts}"

  # the the_http_proxy comes from the parameter passed to ece-import,
  # with --http-proxy. If it's not set, http_proxy will be exported to
  # an empty string here, which in effect will disable the HTTP proxy
  # setting in the shell.
  export http_proxy=${the_http_proxy}

  # long sed from
  # http://stackoverflow.com/questions/1881237/easiest-way-to-extract-the-urls-from-an-html-page-using-sed-or-awk-only
  local list_of_files=$(
    wget $user_and_password \
      --quiet \
      --output-document \
      - $uri | \
      sed -e 's/<a /\n<a /g' | \
      grep ^'<a href' | \
      sed -e 's/<a .*href=['"'"'"]//' \
      -e 's/["'"'"'].*$//' \
      -e '/^$/ d' | \
      egrep -i '.(xml|jpg|jpeg|gif|pdf)$'
  )

  download_files_if_desired $list_of_files
}

## Will only download files which are newer than max_file_age and
## which haven't been downloaded before.
##
## $@ :: list of URIs
function download_files_if_desired() {
  for the_file in $list_of_files; do
    local url_to_download=$(url_to_download $the_file)
    
    if [ $(is_already_downloaded $url_to_download) -eq 1 ]; then
      # not logging anything here as this will create log files in
      # production.
      continue
    fi
    print_and_log "Downloading" $url_to_download "..."
    download_uri_target_to_dir \
      $url_to_download \
      $raw_spool_base_dir/$publication_name/$job_name/ \
      $(basename $the_file)
    local result=$raw_spool_base_dir/$publication_name/$job_name/$(basename $the_file)

    log "Downloaded" $url_to_download "to" $result
    echo $url_to_download >> $(get_state_file)
  done
}

function is_already_downloaded() {
  if [ ! -e $(get_state_file) ]; then
    echo 0
    return
  fi

  if [ $(grep "$1" $(get_state_file) | wc -l) -gt 0 ]; then
    echo 1
    return
  fi

  echo 0
}

function get_state_file() {
  echo $raw_state_base_dir/$publication_name/$job_name/download.state
}


function url_to_download() {

local scanned_url=$url
local filename=$1

local sed_substitution=$(echo "$scanned_url/" | sed -e 's/[]\/()$*.^|[]/\\&/g')
sed_substitution="$sed_substitution\1"
local sed_regex="^\\(.*\\)\$"
local url_to_print=$(echo "$filename" | sed -n "s/$sed_regex/$sed_substitution/p")
echo "$url_to_print"

}
