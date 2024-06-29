#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;

BEGIN {
    use_ok('gfio');
}

# Test file opening for writing
my $filename = 'testfile.txt';
my $fh = gfio::open($filename, 'w');
isa_ok($fh, 'gfio', 'File handle is a gfio object');
$fh->write("Hello, World!\n");
$fh->close;

# Test file opening for reading
$fh = gfio::open($filename, 'r');
isa_ok($fh, 'gfio', 'File handle is a gfio object');
my $content = $fh->read;
is($content, "Hello, World!\n", 'Content read matches expected');
$fh->close;

# Test file listing in a directory
my $dir = '.';
my $file_handle = gfio::readfiles($dir, 'txt', 0, 0);
isa_ok($file_handle, 'HASH', 'Directory read returns a hash reference');
my $num_files = $file_handle->numfiles;
ok($num_files >= 1, 'At least one file found in directory');

# Test getting file information
my $file_info = $file_handle->getfile(1);
isa_ok($file_info, 'HASH', 'File info is a hash reference');
is($file_info->{name}, 'testfile.txt', 'File name matches expected');
ok(-e $file_info->{fullname}, 'File exists');

# Test recursive directory reading
$file_handle = gfio::readfiles($dir, 'txt', 1, 0);
isa_ok($file_handle, 'HASH', 'Recursive directory read returns a hash reference');
$num_files = $file_handle->numfiles;
ok($num_files >= 1, 'At least one file found in directory with recursion');

# Clean up
unlink $filename;

done_testing();
