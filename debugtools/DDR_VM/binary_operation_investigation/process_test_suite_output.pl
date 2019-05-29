#!/usr/bin/perl

# Copyright (c) 2009, 2017 IBM Corp. and others
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which accompanies this
# distribution and is available at https://www.eclipse.org/legal/epl-2.0/
# or the Apache License, Version 2.0 which accompanies this distribution and
# is available at https://www.apache.org/licenses/LICENSE-2.0.
#
# This Source Code may also be made available under the following
# Secondary Licenses when the conditions for such availability set
# forth in the Eclipse Public License, v. 2.0 are satisfied: GNU
# General Public License, version 2 with the GNU Classpath
# Exception [1] and GNU General Public License, version 2 with the
# OpenJDK Assembly Exception [2].
#
# [1] https://www.gnu.org/software/classpath/license.html
# [2] http://openjdk.java.net/legal/assembly-exception.html
#
# SPDX-License-Identifier: EPL-2.0 OR Apache-2.0 OR GPL-2.0 WITH Classpath-exception-2.0 OR LicenseRef-GPL-2.0 WITH Assembly-exception

# Takes the output of the CPP program generated by generate_test_suite.pl
# and turns it into Java code to be pasted into com.ibm.j9ddr.unittests.core.ScalarTest

# Reads input from STDIN. Writes to STDOUT

# Andrew Hall

use strict;
use warnings;

use Text::CSV;

my $in_method = undef;

my $csv = new Text::CSV();

while (my $line = <STDIN>) {
	chomp $line;
	
	if ($line =~ /START SECTION (\S+) (\S+)/) {
		my ($type, $operation) = ($1,$2);
		start_test_method($type,$operation);
	} elsif ($line =~ /SUBSECTION (\S+) WITH (\S+)/) {
		my ($type1,$type2) = ($1,$2);
		
		print <<END;
		
		// Testing $type1 with $type2
END
	} elsif ($line =~ /INVALID: (\S+?),(\S+?),(\S+)/) {
		my ($type1,$operation,$type2) = ($1,$2,$3);
		
		if ($operation ne 'equals') {
			print <<END;
		try {
			//$type1 $operation $type2 is invalid. Make sure it's impossible
			new NumberTest("$operation", $type1, 0x0L, $type2, 0x0L, $type1, 0x0L, $type1, 0x0L).test();
			fail("Expected NoSuchMethodException and didn't get it");
		} catch (NoSuchMethodException ex) {
			//Expected
		}
END
		}
	} else {
		$csv->parse($line);
		
		my ($type1,$value1,$operation,$type2,$value2,$result_type,$result1,$result2) = $csv->fields();
		
		die "Couldn't parse $line" unless defined $result2;
		
		$type1 =~ s/_//g;
		$type2 =~ s/_//g;
		$result_type =~ s/_//g;
		
		if ($operation eq 'equals') {
			$result1 = $result1 eq '1' ? 'true' : 'false';
			$result2 = $result2 eq '1' ? 'true' : 'false';
			
			print <<END;
		//($type1)0x$value1 $operation ($type2)0x$value2 = $result1
		//($type2)0x$value2 $operation ($type1)0x$value1 = $result2
		new EqTest($type1, 0x${value1}L, $type2, 0x${value2}L, $result1, $result2).test();
		
END
		} else {
			print <<END;
		//($type1)0x$value1 $operation ($type2)0x$value2 = ($result_type)0x$result1
		//($type2)0x$value2 $operation ($type1)0x$value1 = ($result_type)0x$result2
		new NumberTest("$operation", $type1, 0x${value1}L, $type2, 0x${value2}L, $result_type, 0x${result1}L, $result_type, 0x${result2}L).test();
		
END
		}
		
	}
}

close_previous_method();

sub close_previous_method
{
	if ($in_method) {
		
		print <<END;
	}

END
		
		$in_method = undef;
	}
}

sub start_test_method
{
	my ($type,$operation) = @_;
	
	$type =~ s/_//g;
	$type = lc $type;
	
	my $method_name = "${type}_${operation}Impl";
	
	close_previous_method();
	
	print <<END;

	public void $method_name() throws Exception
	{
END

	$in_method = 1;
}

