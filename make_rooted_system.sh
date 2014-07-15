# Copyright 2014 ma34s
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#!/bin/bash
# -------------------------------------------------------
# -------------------------------------------------------
func_init_dir()
{
	if [ -z "$1" ]; then
		echo "error: not found MODEL" && exit -1
	fi
	_OUT_DIR=$1

	if [ -d $_OUT_DIR ]; then
		sudo rm -rf $_OUT_DIR
	fi
	mkdir -p $_OUT_DIR
	mkdir -p $_OUT_DIR/tmp
}
# -------------------------------------------------------
func_make_model_select()
{
	_MODEL=""
	_ITEM=""


	_CONFIGS=`ls ./config | grep config_`

	if [ ! -n "$1" ]; then
		_IDX=1
		for _CONF in $_CONFIGS; do
			_SEL_ITEM=`echo $_CONF | cut -d'_' -f2`
			_NAME=`cat ./config/$_CONF | grep DEVICE_NAME | cut -d'=' -f2`
			_ITEM="$_ITEM
$_IDX) $_SEL_ITEM $_NAME"
		   _IDX=`expr $_IDX + 1`
		done

		

		_IDX=`expr $_IDX - 1`
		read -p "$_ITEM
chose model [1-$_IDX] : " _SEL_NUM
		_MODEL=`echo $_CONFIGS | cut -d' ' -f$_SEL_NUM | cut -d'_' -f2`
	else
		for _CONF in $_CONFIGS; do
			_SEL_ITEM=`echo $_CONF | cut -d'_' -f2`
			if [ "$1" = "$_SEL_ITEM" ]; then
				_MODEL=$1
				break
			fi
		done
	fi
	echo $_MODEL
}
# -------------------------------------------------------
func_make_simg2img()
{
	if [ ! -e ./bin/ext4_utils/simg2img ]; then
	    echo ">>>>> make simg2img binary..."
		make -C ./bin/ext4_utils/
	fi
}
# -------------------------------------------------------
func_extract_factoryfs_files()
{
	_TMP_DIR=$1
	_FACTORYFS_DIR=$2
	_FACTORYFS_IMG=$3
	
	# extract factoryfs files
	echo ">>>>> extract system files. wait a few minuts..."
	if [ ! -d $_TMP_DIR/mnt ]; then
		mkdir -p $_TMP_DIR/mnt
	fi
	if [ -d $_FACTORYFS_DIR ]; then
		sudo rm -rf $_FACTORYFS_DIR
	fi
	mkdir -p $_FACTORYFS_DIR

	./bin/ext4_utils/simg2img $_FACTORYFS_IMG $_TMP_DIR/output.img
	sudo mount -o loop,ro,noexec,noload $_TMP_DIR/output.img $_TMP_DIR/mnt
	sudo rsync -av $_TMP_DIR/mnt/ $_FACTORYFS_DIR
	sudo umount $_TMP_DIR/mnt
}

# -------------------------------------------------------
func_repack_factoryfs_files()
{
	_FACTORYFS_DIR=$1
	_FACTORYFS_IMG=$2
	_FACTORYFS_IMG_SIZE=$3
	echo ">>>>> repack system.img..."
	cd ./bin/ext4_utils
	sudo ./make_ext4fs -s -l $_FACTORYFS_IMG_SIZE -a system $_FACTORYFS_IMG $_FACTORYFS_DIR
	cd $BASE_DIR
}

# -------------------------------------------------------
func_make_odin_package()
{
	_OUT_DIR=$1
	_FACTORYFS_IMG=$2
	_IMAGE_FILE=$3
	_OPT_FILES=$4
	echo ">>>>> make odin package..."
	cd $_OUT_DIR
	
	tar cvf $_IMAGE_FILE-gettingroot.tar $_FACTORYFS_IMG $_OPT_FILES
	md5sum -t $_IMAGE_FILE-gettingroot.tar >> $_IMAGE_FILE-gettingroot.tar
	mv $_IMAGE_FILE-gettingroot.tar $_IMAGE_FILE-gettingroot.tar.md5
	sudo rm $_FACTORYFS_IMG
	if [ ! -z $_OPT_FILES ]; then
		sudo rm $_OPT_FILES
	fi
	cd $BASE_DIR
}

# -------------------------------------------------------
func_make_rooting_cache()
{
	_FACTORYFS_DIR=$1
	_STOCK_CACHE_IMG=$2
	_STOCK_RECOVERY_IMG=$3
	_CWM_RECOVERY_IMG=$4
	#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	#todo 
	#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
}
#============================================================================
BASE_DIR=`pwd`

_MODEL_SEL=$1
_BUILD_SEL=$2

MODEL=`func_make_model_select $_MODEL_SEL`
#func_make_model_select $_MODEL_SEL

if [ -z "$MODEL" ]; then
	echo "error: not found MODEL" && exit -1
fi

if [ -f ./img/$MODEL/$FACTORYFS_IMG ]; then
	echo "error: not found image file" && exit -1
fi

OUT_DIR="$BASE_DIR/out/$MODEL"
TMP_DIR="$OUT_DIR/tmp"
FACTORYFS_DIR="$TMP_DIR/factoryfs"

#import model config
. ./config/config_$MODEL

BUILD_SELECT=`func_make_build_select $_BUILD_SEL`
#IMAGE_FILE=$MODEL-$BUILD_SELECT

SU_INSTALL_FUNCTION=`func_select_method $SU_INSTALL_FUNC`

echo $SU_INSTALL_FUNCTION select!

echo "===== $MODEL make start ====="
# init out/work dir
func_init_dir out/$MODEL

# make simg2img
func_make_simg2img

# extract factoryfs files
func_extract_factoryfs_files $TMP_DIR $FACTORYFS_DIR ./img/$MODEL/$FACTORYFS_IMG

#make getting root files
func_make_rooting_cache $FACTORYFS_DIR ./img/$MODEL/$FACTORYFS_IMG ./img/$MODEL/$OPT_FILES ./img/$MODEL/$CWM_FILES

# repack
func_repack_factoryfs_files $FACTORYFS_DIR $OUT_DIR/$FACTORYFS_IMG $FACTORYFS_IMG_SIZE
# make package
if [ ! -z ./img/$MODEL/$OPT_FILES ]; then
	cp ./img/$MODEL/$OPT_FILES $OUT_DIR
fi
func_make_odin_package $OUT_DIR $FACTORYFS_IMG $IMAGE_FILE $OPT_FILES

# cleanup
echo ">>>>> cleanup..."
sudo rm -rf $TMP_DIR

echo "===== make end ====="
