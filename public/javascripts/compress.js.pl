#!/usr/X11R6/bin/perl

%ntwNamesMap    = '';
$ntwNamesCount  = 0;
%privNamesMap   = '';
$privNamesCount = 0;
$tmpOut         = '';
$out            = '';

open (LOG, ">/tmp/jscompress.log") || warn "Could not open /tmp/jscompress.log file for logging!";

while (<>) {
		# Record _GLOB_ global variables and map them to _NTW_0, _NTW_1, ...
	while (/(_GLOB_\w+)/isg) {
		if (!$ntwNamesMap{$1}) {
			$ntwNamesMap{$1} = "_NTW_".$ntwNamesCount;
			$ntwNamesCount++;
		}
	}

	while (/(_PRIV_\w+)/isg) {
		if (!$privNamesMap{$1}) {
			$privNamesMap{$1} = "_v".$privNamesCount;
			$privNamesCount++;
		}
	}

		# Last thing to do ... Record if non-empty
	if ($_) {
		$tmpOut .= $_;
	}
}

$out = $tmpOut;

	# Replace all global long GLOB_ names with short _NTW_ variables
for $k (keys  %ntwNamesMap) {
	print LOG "REPLACING '$k' with '".$ntwNamesMap{$k}."'\n";
	$out =~ s/([^\w_])$k([^\w\d_])/$1$ntwNamesMap{$k}$2/isg;
}

   # Replace all private _PRIV_ names with short _v variables
for $k (keys  %privNamesMap) {
	print LOG "REPLACING '$k' with '".$privNamesMap{$k}."'\n";
	$out =~ s/([^\w_])$k([^\w\d_])/$1$privNamesMap{$k}$2/isg;
}

# Output the compressed JS
print $out;
close LOG;
