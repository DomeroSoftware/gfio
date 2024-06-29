#!/usr/bin/perl
use strict;
use warnings;
use gfio;  # Assuming gfio.pm is in the same directory or included in @INC

# Example usage of functions from gfio.pm module

# Example 1: Change file owner and group
my $filename = 'example.txt';
my $new_user = 'newuser';
my $new_group = 'newgroup';
change_file_owner($filename, $new_user, $new_group);

# Example 2: Create directories recursively
my $newdir = '/path/to/new/directory';
make_directories($newdir);

# Example 3: Read directories and files
my $dir_to_read = '/path/to/directory';
my $recursive = 1;  # Read subdirectories recursively
my $verbose = 1;    # Enable verbose output

# Read directories and files
my $dir_info = read_directories($dir_to_read, $recursive, $verbose);

# Example 4: Read files with extension filtering
my $extensions = 'txt, pdf';  # Filter by these extensions
my $include_subdirs = 1;      # Include files from subdirectories
my $files_info = read_files($dir_to_read, $extensions, $include_subdirs, $verbose);

# Example 5: Process file contents
my $file_to_process = 'example.txt';
my $tab_char = '    ';  # Substitute tab characters with 4 spaces
process_file_contents($file_to_process, $tab_char);

# Functions implementation

sub change_file_owner {
    my ($filename, $user, $group) = @_;
    print "Changing owner and group of $filename to $user:$group...\n";
    changeowner($filename, $user, $group);
    print "Owner and group changed successfully.\n";
}

sub make_directories {
    my ($dir) = @_;
    print "Creating directory $dir...\n";
    makedir($dir);
    print "Directory created successfully.\n";
}

sub read_directories {
    my ($dir, $recursive, $verbose) = @_;
    print "Reading directories from $dir...\n";
    my $dir_info = dirlist($dir, $recursive);
    
    if ($dir_info->{exist}) {
        print "Directories:\n";
        foreach my $d (@{$dir_info->{dirs}}) {
            print "- $d->[2]\n";
        }
        print "Files:\n";
        foreach my $f (@{$dir_info->{files}}) {
            print "- $f->[2]\n";
        }
    } else {
        print "Directory $dir does not exist.\n";
    }
    
    return $dir_info;
}

sub read_files {
    my ($dir, $extensions, $recursive, $verbose) = @_;
    print "Reading files from $dir with extensions: $extensions...\n";
    my $files_info = readfiles($dir, $extensions, $recursive, $verbose);
    
    if ($files_info->{exist}) {
        print "Matching files:\n";
        foreach my $f (@{$files_info->{list}}) {
            print "- $f->[2]\n";
        }
    } else {
        print "Directory $dir does not exist or no matching files found.\n";
    }
    
    return $files_info;
}

sub process_file_contents {
    my ($filename, $tab_char) = @_;
    print "Processing contents of $filename...\n";
    my $lines = lines($filename, $tab_char);
    
    if ($lines) {
        print "Contents:\n";
        foreach my $line (@$lines) {
            print "$line\n";
        }
    } else {
        print "File $filename does not exist.\n";
    }
}
