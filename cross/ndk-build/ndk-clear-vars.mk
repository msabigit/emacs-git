# Copyright 2023 Free Software Foundation, Inc.

# This file is part of GNU Emacs.

# GNU Emacs is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# GNU Emacs is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

# ndk-build works by including a bunch of Makefiles which set
# variables, and then having those Makefiles include another makefile
# which actually builds targets.

undefine LOCAL_MODULE
undefine LOCAL_MODULE_FILENAME
undefine LOCAL_SRC_FILES
undefine LOCAL_CPP_EXTENSION
undefine LOCAL_CPP_FEATURES
undefine LOCAL_C_INCLUDES
undefine LOCAL_CFLAGS
undefine LOCAL_CPPFLAGS
undefine LOCAL_STATIC_LIBRARIES
undefine LOCAL_SHARED_LIBRARIES
undefine LOCAL_WHOLE_STATIC_LIBRARIES
undefine LOCAL_LDLIBS
undefine LOCAL_LDFLAGS
undefine LOCAL_ALLOW_UNDEFINED_SYMBOLS
undefine LOCAL_ARM_MODE
undefine LOCAL_ARM_NEON
undefine LOCAL_DISABLE_FORMAT_STRING_CHECKS
undefine LOCAL_EXPORT_CFLAGS
undefine LOCAL_EXPORT_CPPFLAGS
undefine LOCAL_EXPORT_C_INCLUDES
undefine LOCAL_EXPORT_C_INCLUDE_DIRS
undefine LOCAL_EXPORT_LDFLAGS
undefine LOCAL_EXPORT_LDLIBS

# AOSP extensions.
undefine LOCAL_SRC_FILES_$(NDK_BUILD_ARCH)
undefine LOCAL_ASFLAGS_$(NDK_BUILD_ARCH)
undefine LOCAL_CFLAGS_$(NDK_BUILD_ARCH)
undefine LOCAL_ADDITIONAL_DEPENDENCIES
undefine LOCAL_CLANG_ASFLAGS_$(NDK_BUILD_ARCH)
undefine LOCAL_IS_HOST_MODULE

# Emacs extensions!
undefine LOCAL_ASM_RULE_DEFINED
undefine LOCAL_ASM_RULE
undefine LOCAL_C_ADDITIONAL_FLAGS