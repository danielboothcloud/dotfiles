# Kata session pods have no /dev/fuse, so fuse-overlayfs cannot run there and
# kernel overlay refuses a virtio-fs upper dir; vfs works anywhere (slower, more disk).
if [ ! -e /dev/fuse ]; then
  : "${STORAGE_DRIVER:=vfs}"; export STORAGE_DRIVER
fi
