#===============================================================================
#
# Copyright (C) 2021-2023 gba-toolchain contributors
# For conditions of distribution and use, see copyright notice in LICENSE.md
#
#===============================================================================

# Create include() function
if(NOT CMAKE_SCRIPT_MODE_FILE)
    set(BIN2S_SCRIPT "${CMAKE_CURRENT_LIST_FILE}")
    function(bin2s output)
        execute_process(
            COMMAND "${CMAKE_COMMAND}" -P "${BIN2S_SCRIPT}" -- "${ARGN}"
            OUTPUT_VARIABLE outputVariable OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        set("${output}" "${outputVariable}" PARENT_SCOPE)
    endfunction()
    return()
endif()
unset(CMAKE_SCRIPT_MODE_FILE) # Enable nested include()

# Collect arguments past -- into CMAKE_ARGN
foreach(ii RANGE ${CMAKE_ARGC})
    if(${ii} EQUAL ${CMAKE_ARGC})
        break()
    elseif("${CMAKE_ARGV${ii}}" STREQUAL --)
        set(start ${ii})
    elseif(DEFINED start)
        list(APPEND CMAKE_ARGN "${CMAKE_ARGV${ii}}")
    endif()
endforeach()
unset(start)

# Script begin

function(split var size)
    string(LENGTH ${${var}} len)

    set(chunks)
    foreach(ii RANGE 0 ${len} ${size})
        string(SUBSTRING ${${var}} ${ii} ${size} chunk)
        list(APPEND chunks ${chunk})
    endforeach ()

    set(${var} ${chunks} PARENT_SCOPE)
endfunction()

execute_process(COMMAND "${CMAKE_COMMAND}" -E echo "/* Generated by Bin2s.cmake */")

foreach(arg ${CMAKE_ARGN})
    file(READ "${arg}" data HEX)
    string(LENGTH ${data} size)
    split(data 32)

    get_filename_component(arg "${arg}" NAME)
    string(REGEX REPLACE "[^a-zA-Z0-9_]" "_" arg "${arg}")

    execute_process(COMMAND "${CMAKE_COMMAND}" -E echo_append "    .section .rodata.${arg}, \"a\"
    .balign
    .global ${arg}
${arg}:
    ")

    foreach(line ${data})
        split(line 2)
        list(TRANSFORM line PREPEND "0x")
        list(JOIN line ", " line)

        execute_process(COMMAND "${CMAKE_COMMAND}" -E echo_append ".byte ${line}
    ")
    endforeach()

    math(EXPR size "${size} / 2")

    execute_process(COMMAND "${CMAKE_COMMAND}" -E echo_append "
    .global ${arg}_end
${arg}_end:

    .global ${arg}_size
    .balign 4
${arg}_size: .int ${size}
")
endforeach()