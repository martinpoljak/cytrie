include "settings.pxi"

IF INT_SIZE == 4:
	include "platforms/platform_int4byte.pxi"
ELIF INT_SIZE == 8:
	include "platforms/platform_int8byte.pxi"
ELIF INT_SIZE == 2:
	include "platforms/platform_int2byte.pxi"
ELSE:
	include "platforms/platform_char.pxi"
