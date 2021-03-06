# Copyright 2004-2016 Cray Inc.
# Other additional copyright holders may be indicated within.
#
# The entirety of this work is licensed under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
#
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ifndef CHPL_MAKE_HOME
export CHPL_MAKE_HOME=$(shell pwd)/..
endif

# Generate tags only if $TAGS turned on explicitly, or if $CHPL_DEVELOPER is on
ifdef CHPL_DEVELOPER
TAGS=1
endif

# Generate tags command, dependent on if Make variable, TAGS == 1
ifeq ($(TAGS), 1)
TAGS_COMMAND=-@($(CHPL_MAKE_HOME)/util/chpltags -r . > /dev/null 2>&1 && echo "Updating TAGS..." || echo "Tags utility not available.  Skipping tags generation.")
endif

CHPL_MAKE_HOST_TARGET = --target
include $(CHPL_MAKE_HOME)/make/Makefile.base

SYS_MODULES_DIR=standard/gen/$(CHPL_MAKE_PLATFORM)-$(CHPL_MAKE_COMPILER)
SYS_CTYPES_MODULE_DOC=standard/SysCTypes.chpl
SYS_CTYPES_MODULE=$(SYS_MODULES_DIR)/SysCTypes.chpl

MODULE_SPHINX=${CHPL_MAKE_HOME}/modules/sphinx
DOC_SPHINX=${CHPL_MAKE_HOME}/doc/sphinx

default: all

all: $(SYS_CTYPES_MODULE)
	$(TAGS_COMMAND)

clean: FORCE

cleanall: FORCE

clobber: FORCE clean-documentation
	rm -rf standard/gen
	rm -f TAGS tags

depend:

MAKE_SYS_BASIC_TYPES=$(CHPL_MAKE_HOME)/util/config/make_sys_basic_types.py

$(SYS_CTYPES_MODULE): $(MAKE_SYS_BASIC_TYPES)
	mkdir -p $(@D)
	cd $(@D) && $(MAKE_SYS_BASIC_TYPES) $(@F)

$(SYS_CTYPES_MODULE_DOC): $(MAKE_SYS_BASIC_TYPES)
	mkdir -p $(@D)
	cd $(@D) && $(MAKE_SYS_BASIC_TYPES) --doc $(@F)


MODULES_TO_DOCUMENT = \
	standard/Assert.chpl \
	standard/Barrier.chpl \
	standard/BitOps.chpl \
	standard/Buffers.chpl \
	standard/CommDiagnostics.chpl \
	standard/DynamicIters.chpl \
	standard/Error.chpl \
	standard/FileSystem.chpl \
	standard/GMP.chpl \
	standard/Help.chpl \
	standard/IO.chpl \
	standard/List.chpl \
	standard/Math.chpl \
	standard/Memory.chpl \
	standard/Path.chpl \
	standard/Random.chpl \
	standard/Reflection.chpl \
	standard/Regexp.chpl \
	standard/Spawn.chpl \
	standard/Sys.chpl \
	standard/SysBasic.chpl \
	standard/Time.chpl \
	standard/Types.chpl \
	standard/UtilReplicatedVar.chpl \
	$(SYS_CTYPES_MODULE_DOC)

PACKAGES_TO_DOCUMENT = \
	packages/BLAS.chpl \
	packages/Curl.chpl \
	packages/FFTW.chpl \
	packages/FFTW_MT.chpl \
	packages/HDFS.chpl \
	packages/HDFSiterator.chpl \
	packages/LAPACK.chpl \
	packages/Norm.chpl \
	packages/RecordParser.chpl \
	packages/Search.chpl \
	packages/Sort.chpl \
	packages/VisualDebug.chpl

DISTS_TO_DOCUMENT = \
	dists/BlockCycDist.chpl \
	dists/BlockDist.chpl \
	dists/CyclicDist.chpl \
	dists/DimensionalDist2D.chpl \
	dists/PrivateDist.chpl \
	dists/ReplicatedDist.chpl \
	dists/dims/BlockCycDim.chpl \
	dists/dims/BlockDim.chpl \
	dists/dims/ReplicatedDim.chpl \
	layouts/LayoutCSR.chpl \

INTERNAL_MODULES_TO_DOCUMENT =          \
	internal/Atomics.chpl                 \
	internal/ChapelArray.chpl             \
	internal/ChapelComplex_forDocs.chpl   \
	internal/ChapelIO.chpl                \
	internal/ChapelIteratorSupport.chpl   \
	internal/ChapelLocale.chpl    \
	internal/UtilMisc_forDocs.chpl 	      \
	internal/ChapelRange.chpl             \
	internal/String.chpl                  \
	internal/ChapelSyncvar.chpl           \
	internal/ChapelTuple.chpl \
	internal/ChapelEnv.chpl


documentation: $(SYS_CTYPES_MODULE_DOC)
	export CHPLDOC_AUTHOR='Cray Inc' && \
	$(CHPLDOC) --save-sphinx ${MODULE_SPHINX} --no-html $(MODULES_TO_DOCUMENT) $(DISTS_TO_DOCUMENT) $(PACKAGES_TO_DOCUMENT) $(INTERNAL_MODULES_TO_DOCUMENT)
	./internal/fixInternalDocs.sh ${MODULE_SPHINX}
	./dists/fixDistDocs.perl      ${MODULE_SPHINX}
	cp -rf ${MODULE_SPHINX}/source/modules/standard ${DOC_SPHINX}/source/modules/
	cp -rf ${MODULE_SPHINX}/source/modules/packages ${DOC_SPHINX}/source/modules/
	cp -rf ${MODULE_SPHINX}/source/modules/dists    ${DOC_SPHINX}/source/modules/
	cp -rf ${MODULE_SPHINX}/source/modules/layouts  ${DOC_SPHINX}/source/modules/
	cp -rf ${MODULE_SPHINX}/source/modules/internal ${DOC_SPHINX}/source/modules/
	rm -rf ${MODULE_SPHINX}
	rm -f ${CHPL_MAKE_HOME}/modules/$(SYS_CTYPES_MODULE_DOC)

clean-documentation:
	rm -rf ./docs
	rm -rf $(MODULE_SPHINX)

FORCE:

