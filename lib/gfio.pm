#!/usr/bin/perl
################################################################################

 #############################################################################
 #                                                                           #
 #   Eureka File System                                                      #
 #   (C) 2017 Domero, Groningen, NL                                          #
 #   ALL RIGHTS RESERVED                                                     #
 #                                                                           #
 #############################################################################

package gfio;

=head1 NAME

gfio - Perl module for file and directory operations

=head1 SYNOPSIS

    use gfio;

    # Example usage:
    my $file = gfio->newfile("example.txt");
    $file->write("Hello, world!\n");
    print $file->read(13);

=head1 DESCRIPTION

The gfio module provides a set of functions for handling file and directory operations in Perl.

=head1 CONSTANTS

=head2 %OPENED

Global hash storing information about opened files.

=cut

use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION     = '1.0.13';
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(open close seek tell read write insert extract readlines filesize truncate create newfile lock unlock locked changeowner content append copy makedir closeall readfiles readdirs numfiles getfile);

use Fcntl qw (:DEFAULT :flock);
use gerr qw(error);

my %OPENED=();

1;

################################################################################

=head1 EXAMPLES

=head2 Writing to a File

To write content to a file using `gfio`:

    use gfio;
    my $fh = gfio::open('filename.txt', 'w');
    $fh->write("Hello, World!\n");
    $fh->close();

=head2 Reading from a File

To read content from a file:

    use gfio;
    my $fh = gfio::open('filename.txt', 'r');
    my $content = $fh->read();
    $fh->close();
    print "File content: $content\n";

=head2 Appending to a File

To append data to the end of an existing file:

    use gfio;
    my $fh = gfio::open('filename.txt', 'a');
    $fh->append("More data\n");
    $fh->close();

=head2 Creating a New File with Content

To create a new file with specified content:

    use gfio;
    gfio::create('newfile.txt', "Initial content\n");

=head2 Copying a File

To copy a file from source to destination:

    use gfio;
    gfio::copy('sourcefile.txt', 'destination.txt');

=head2 Reading Directory Contents

To list directories and files in a directory:

    use gfio;
    my $dir = gfio::dirlist('/path/to/directory', 1);  # Recursive listing
    foreach my $file (@{$dir->{files}}) {
        print "File: $file->[2]\n";
    }
    foreach my $dir (@{$dir->{dirs}}) {
        print "Directory: $dir->[2]\n";
    }

=head2 Handling File Permissions

To change the owner of a file:

    use gfio;
    gfio::changeowner('filename.txt', 'newowner', 'newgroup');

=head2 Error Handling

To handle errors while working with files:

    use gfio;
    eval {
        my $fh = gfio::open('nonexistent.txt', 'r');
        my $content = $fh->read();
        $fh->close();
        print "File content: $content\n";
    };
    if ($@) {
        warn "Error: $@\n";
    }

=head2 Working with File Flags

To use file flags for file operations:

    use gfio;
    my $fh = gfio::open('filename.txt', 'w', 'O_CREAT|O_TRUNC');
    $fh->write("New file content\n");
    $fh->close();

=cut

################################################################################
#
# Exported
#
# $gfioh=newfile(filename,content,[no_read])
#  * creates a file with content, and returns the handle for further processing.
#
# $gfioh=open(filename,[r|w|a])
#  * append will overrule write, use write or append to create
#
# $gfioh->close
#  * unlocks, flushes and closes a file
#
# $position=$gfioh->tell
#  * returns the current position to write to or read from in a file
#
# $gfioh->seek($position)
#  * jumps to position in a file, position may not be larger than filesize
#
# $length=$gfioh->filesize
#  * returns the length in bytes of a file.
#
# $gfioh->truncate(length)
#  * if the size of a file is larger than length, will truncate the file to length, and apply changes to size and position if necessary.
#
# $data=$gfioh->read(length,stopatend)
#  * returns length bytes read from a file.
#
# $datapointer=$gfioh->readptr(length)
#  * returns a SCALAR-reference to length bytes read from a file.
#
# $gfioh->write(data)
#  * writes data to a file. data may be a SCALAR-reference.
#
# $gfioh->insert(data,[append])
#  * inserts data into a file at the current position, and increases the filesize accordingly. data may be a SCALAR-reference. 
#  * if append is set, the data will be appended in stead of inserted.
#
# $gfioh->appenddata(data)
#  * Appends data to the end of the open file-handle (for closed files use append).
#
# $gfioh->extract(length)
#  * removes length bytes from a file at the current position and truncates the file. returns the extracted data.
#
# $gfioh->lock
#  * exclusively increases the lock on a file.
#
# $gfioh->unlock
#  * decreases a lock on a file, if no locks remain, will unlock the file. Always use the same number of locks and unlocks!
#
# closeall
#  * closes all cureently open files
#
# makedir(dirname,[mode])
#  * default mode = 0700 (rwx)
#
# create(filename,[content],[not_empty],[mode])
#  * creates a file with content. if not_empty is set, will not create empty files. default mode = 0600 (rw)
#
# changeowner(filename,user,group)
#  * changes ownership of a file
#
# content(filename,[offset],[length])
#  * returns the content of a file, or a part of it, without it staying opened.
#
# append(file,content)
#  * appends content to file.
#
# copy(source_filename,destination_filename,[no_overwrite])
#  * copies a file, will not overwrite is flag is set.
#
# $gfioh=readfiles(directory,extlist,recursive,verbose)
#  * read all files in a directory. extlist may be "ext,ext,..", empty or '*'.
#
# $gfioh=readdirs(directory,recursive,verbose)
#  * reads a directory-tree.
#
# total=$gfioh->numfiles
#  * returns the number of files read by readfiles or readdirs.
#
# \%infohash=$gfioh->getfile(number)
#  * returns information on file number read by readfiles or readdirs, number must be between 1 and $gfioh->numfiles.
#    The list contains (hash): barename, ext, name, dir, fullname, level, mode, size, atime, mtime, ctime
#
################################################################################
#
# Flag         Description
# --------------------------------------------------------
# O_RDONLY     Read only.
# O_WRONLY     Write only.
# O_RDWR       Read and write.
# O_CREAT      Create the file if it doesn't already exist.
# O_EXCL       Fail if the file already exists.
# O_APPEND     Append to an existing file.
# O_TRUNC      Truncate the file before opening.
# O_NONBLOCK   Non-blocking mode.
# O_NDELAY     Equivalent of O_NONBLOCK.
# O_EXLOCK     Lock using flock and LOCK_EX.
# O_SHLOCK     Lock using flock and LOCK_SH.
# O_DIRECTORY  Fail if the file is not a directory.
# O_NOFOLLOW   Fail if the last path component is a symbolic link.
# O_BINARY     Open in binary mode (implies a call to binmode).
# O_LARGEFILE  Open with large (>2GB) file support.
# O_SYNC       Write data physically to the disk, instead of write buffer.
# O_NOCTTY     Don't make the terminal file being opened the process's controlling terminal, even if you don't have one yet.
#
################################################################################

=head1 FUNCTIONS

=head2 open

    my $gfio = open($filename, $mode)

Opens a file with the specified mode (r, w, a, etc.).

This function opens a file specified by C<$filename> with the mode specified
by C<$mode>. The mode can be one of 'r' (read), 'w' (write), or 'a' (append).
If no mode is specified, 'r' (read) is assumed.

Upon successful opening, a file handle object is returned which can be used
to perform file operations such as reading, writing, seeking, etc.

Throws an error via the C<gerr::error> function if:
- The file specified by C<$filename> does not exist and is not opened in write
  or append mode.
- Cannot overwrite a directory or symbolic link with a file.
- Cannot open the file in the specified mode due to permission issues or
  other system errors.

=cut

sub open {
    my ($filename, $mode) = @_;

    # Initialize file handle object
    my $gfio = {};
    bless $gfio;

    # Store file and open mode in object attributes
    $gfio->{file} = $filename;
    $gfio->{openmode} = $mode;

    # Determine read, write, and append flags based on mode
    $gfio->{read} = 0;
    $gfio->{write} = 0;
    $gfio->{append} = 0;

    if (!defined $mode || $mode =~ /r/i) {
        $gfio->{read} = 1;
    }
    if (defined $mode && $mode =~ /w/i) {
        $gfio->{write} = 1;
    }
    if (defined $mode && $mode =~ /a/i) {
        $gfio->{append} = 1;
    }

    # Handle file existence and mode-specific actions
    if (!-e $filename) {
        if (!$gfio->{write} && !$gfio->{append}) {
            error("GFIO.Open: File '$filename' does not exist and mode does not allow creation");
        } else {
            $gfio->makepath;  # Create directory path if it doesn't exist
            if ($gfio->{read}) {
                sysopen($gfio->{handle}, $filename, O_CREAT | O_RDWR | O_BINARY)
                    or error("GFIO.Open: Cannot open '$filename' in mode 'r': $!");
            } else {
                sysopen($gfio->{handle}, $filename, O_CREAT | O_WRONLY | O_BINARY)
                    or error("GFIO.Open: Cannot open '$filename' in mode 'w': $!");
            }
        }
    }
    elsif (!-f $filename) {
        error("GFIO.Open: Cannot overwrite directory '$filename' with a file") if (-d $filename);
        error("GFIO.Open: Cannot overwrite symlink '$filename' with a file") if (-l $filename);
        error("GFIO.Open: Cannot overwrite '$filename' with a file");
    }

    # Handle append mode separately
    if ($gfio->{append}) {
        if ($gfio->{read}) {
            sysopen($gfio->{handle}, $filename, O_APPEND | O_RDWR | O_BINARY)
                or error("GFIO.Open: Cannot open '$filename' in mode 'ar': $!");
        } else {
            sysopen($gfio->{handle}, $filename, O_APPEND | O_WRONLY | O_BINARY)
                or error("GFIO.Open: Cannot open '$filename' in mode 'a': $!");
        }
    } elsif ($gfio->{write}) {
        if ($gfio->{read}) {
            sysopen($gfio->{handle}, $filename, O_RDWR | O_BINARY)
                or error("GFIO.Open: Cannot open '$filename' in mode 'rw': $!");
        } else {
            sysopen($gfio->{handle}, $filename, O_WRONLY | O_BINARY)
                or error("GFIO.Open: Cannot open '$filename' in mode 'w': $!");
        }
    } else {
        sysopen($gfio->{handle}, $filename, O_RDONLY | O_BINARY)
            or error("GFIO.Open: Cannot open '$filename' in mode 'r': $!");
    }

    # Retrieve file size and set initial position
    my @st = stat($filename);
    $gfio->{size} = $st[7];
    if ($gfio->{append}) {
        $gfio->{position} = $gfio->{size};
    } else {
        $gfio->{position} = 0;
    }

    # Mark file as opened and unlocked
    $gfio->{opened} = 1;
    $gfio->{locked} = 0;

    # Store file handle object in global hash
    $OPENED{$filename} = $gfio;

    return $gfio;
}

################################################################################

=head2 close

    $gfio->close()

Closes a file handle previously opened with the `open` method.

This function closes the file associated with the file handle object C<$filename>.
If the file handle object is not open, no action is taken.

=cut

sub close {
    my ($gfio) = @_;

    # Check if the file handle is opened
    if ($gfio->{opened}) {
        # Flush any buffered output
        my $oldh = select $gfio->{handle};
        $| = 1;  # Turn on autoflush
        select($oldh);  # Restore previous handle

        # Ensure the file is unlocked before closing
        while ($gfio->{locked}) {
            $gfio->unlock;  # Call unlock method to release locks
        }

        # Close the file handle
        close($gfio->{handle});
        $gfio->{opened} = 0;  # Mark file as closed

        # Remove file handle object from global hash
        delete $OPENED{$gfio->{file}};
    }
}

################################################################################

=head2 closeall

    closeall()

Closes all opened file handles.

This function iterates through all currently opened file handles stored in the global
hash C<%OPENED> and calls the C<close> method on each file handle object to close them.

=cut

sub closeall {
    foreach my $file (keys %OPENED) {
        $OPENED{$file}->close;  # Call close method on each opened file handle
    }
}

################################################################################

=head2 filesize

    $gfio->filesize()

Returns the size of the file associated with the file handle object.

This function retrieves and returns the size of the file in bytes by accessing the 
C<size> attribute of the file handle object.

=cut

sub filesize {
    my ($gfio) = @_;
    return $gfio->{size};
}

################################################################################

=head2 read

    $gfio->read($length, $stop_at_end)

Reads a specified length of data from the file associated with the file handle object.

This function reads data from the current position in the file and advances the position
by the amount read. It returns the data read as a string.

Parameters:
- $length: The number of bytes to read from the file.
- $stop_at_end: Optional. If set to a true value, the function stops reading when reaching
  the end of the file; otherwise, it throws an error.

Returns:
- A string containing the data read from the file.

=cut

sub read {
    my ($gfio, $length, $stop_at_end) = @_;

    # Validate parameters and handle errors
    if (!$length) {
        return "";  # Return empty string if $length is zero
    }
    if (!$gfio->{opened}) {
        error("GFIO.Read: File '$gfio->{file}' is closed");
    }
    if (!$gfio->{read}) {
        error("GFIO.Read: File '$gfio->{file}' is read-protected");
    }
    if ($gfio->{position} + $length > $gfio->{size}) {
        if ($gfio->{position} > $gfio->{size}) {
            error("GFIO.Read: Trying to read beyond the end of file '$gfio->{file}', position=$gfio->{position} len=$length size=$gfio->{size}");
        }
        elsif ($stop_at_end) {
            my $max_length = $gfio->{size} - $gfio->{position};
            if ($length > $max_length) {
                $length = $max_length;
            }
        }
        else {
            error("GFIO.Read: Trying to read beyond the end of file '$gfio->{file}', position=$gfio->{position} len=$length size=$gfio->{size}");
        }
    }

    # Seek to the current position and read data
    sysseek($gfio->{handle}, $gfio->{position}, 0) || error("GFIO.Read: Error seeking in file '$gfio->{file}' pos=$gfio->{position}: $!");
    my $data;
    sysread($gfio->{handle}, $data, $length) || error("GFIO.Read: Error reading from file '$gfio->{file}', len=$length: $!");

    # Update the position after reading
    $gfio->{position} += $length;

    return $data;
}

################################################################################

=head2 readptr

    $gfio->readptr($length, $error_mode)

Reads a specified length of data from the file and returns a reference to the data.

This function reads data from the current position in the file and advances the position
by the amount read. It returns a scalar reference to the data read.

Parameters:
- $length: The number of bytes to read from the file.
- $error_mode: Optional. If set to a true value, the function throws an error when
  attempting to read beyond the end of the file; otherwise, it reads up to the end
  of the file without error.

Returns:
- A scalar reference containing the data read from the file.

=cut

sub readptr {
    my ($gfio, $length, $error_mode) = @_;

    # Validate parameters and handle errors
    if (!$length) {
        my $empty_data = "";
        return \$empty_data;  # Return reference to an empty scalar if $length is zero
    }
    if (!$gfio->{opened}) {
        error("GFIO.ReadPtr: File '$gfio->{file}' is closed");
    }
    if (!$gfio->{read}) {
        error("GFIO.ReadPtr: File '$gfio->{file}' is read-protected");
    }
    if ($gfio->{position} > $gfio->{size}) {
        $gfio->{position} = $gfio->{size};
    }
    if ($gfio->{position} + $length > $gfio->{size}) {
        if ($error_mode) {
            error("GFIO.ReadPtr: Trying to read beyond the boundaries of file '$gfio->{file}', position=$gfio->{position} len=$length size=$gfio->{size}");
        }
        else {
            $length = $gfio->{size} - $gfio->{position};
        }
    }

    # Seek to the current position and read data
    sysseek($gfio->{handle}, $gfio->{position}, 0) || error("GFIO.ReadPtr: Error seeking in file '$gfio->{file}' pos=$gfio->{position}: $!");
    my $data;
    sysread($gfio->{handle}, $data, $length) || error("GFIO.ReadPtr: Error reading from file '$gfio->{file}', len=$length: $!");

    # Update the position after reading
    $gfio->{position} += $length;

    return \$data;
}

################################################################################

=head2 readlines

    readlines($filename)

Reads all lines from a file into an array.

This function reads all lines from the specified file and returns them as an array,
where each element of the array represents a line from the file.

Parameters:
- $filename: The name of the file to read lines from.

Returns:
- An array reference containing all lines read from the file.

=cut

sub readlines {
    my ($filename) = @_;

    # Validate filename
    if (!$filename) {
        error("GFIO.readlines: No filename given");
    }
    if (!-e $filename) {
        error("GFIO.readlines: File '$filename' does not exist");
    }
    if (!-f $filename) {
        error("GFIO.readlines: '$filename' is not a plain file");
    }

    # Open file for reading
    my $fh = gfio::open($filename, 'r');
    my $size = (-s $filename);  # Get file size
    my $txt = $fh->read($size);  # Read entire file content
    $fh->close;  # Close file handle

    my $lines = [];  # Array to store lines
    my $curline = "";  # Current line buffer
    my $i = 0;  # Index for iterating through characters

    # Iterate through the text to parse lines
    while ($i < $size) {
        my $c = substr($txt, $i, 1);
        my $cc = ord($c);

        # Check for line endings
        if ($cc != 13) {  # Skip carriage return
            if ($cc == 10) {  # Newline character
                push @{$lines}, $curline;  # Store current line
                $curline = "";  # Reset current line buffer
            } else {
                $curline .= $c;  # Append character to current line buffer
            }
        }
        $i++;
    }

    # If there's remaining content in $curline, add it as the last line
    if (length($curline) > 0) {
        push @{$lines}, $curline;
    }

    return $lines;  # Return array reference containing all lines read from the file
}

################################################################################

=head2 write

    $gfio->write($data, $nonil)

Writes data to a file.

This function writes the provided data to the file associated with the GFIO object (`$gfio`).

Parameters:
- $data: The data to be written. Can be a scalar or a reference to a scalar.
- $nonil: Optional. If set and $data is undefined, an error will be thrown.

Returns:
- The GFIO object itself.

=cut

sub write {
    my ($gfio, $data, $nonil) = @_;

    # Unwrap scalar references
    if (ref($data) eq 'SCALAR') {
        $data = ${$data};
    }

    # Handle nil (undefined) data if not allowed
    if (!defined $data) {
        if ($nonil) {
            error("GFIO.Write: Trying to write empty data, while prohibited");
        }
        return $gfio;
    }

    # Validate file is open for writing
    if (!$gfio->{opened}) {
        error("GFIO.Write: File '$gfio->{file}' is closed");
    }

    # Check if file is writable
    if (!$gfio->{write} && !$gfio->{append}) {
        error("GFIO.Write: File '$gfio->{file}' is write-protected");
    }

    # Seek to current position in file
    sysseek($gfio->{handle}, $gfio->{position}, 0) || error("GFIO.Write: Error seeking in file '$gfio->{file}' pos=$gfio->{position}: $!");

    # Write data to file
    eval {
        syswrite($gfio->{handle}, $data) || error("GFIO.Write: Error writing to file '$gfio->{file}', len=" . length($data) . ": $!");
    };
    if ($@) {
        error("GFIO.Write: Error writing to file '$gfio->{file}', len=" . length($data) . ": $@");
    }

    # Update position and file size
    $gfio->{position} += length($data);
    if ($gfio->{position} > $gfio->{size}) {
        $gfio->{size} = $gfio->{position};
    }

    return $gfio;
}

################################################################################

=head2 truncate

    $gfio->truncate($length)

Truncates a file to a specified length.

This function truncates the file associated with the GFIO object (`$gfio`) to
the specified length. If the current size of the file is less than or equal to the
specified length, the function returns without making any changes.

Parameters:
- $length: The new size to which the file should be truncated.

Returns:
- The GFIO object itself.

=cut

sub truncate {
    my ($gfio, $length) = @_;

    # Check if truncation is necessary
    if ($gfio->{size} <= $length) {
        return $gfio;
    }

    # Truncate the file to the specified length
    truncate($gfio->{handle}, $length);

    # Adjust position if necessary
    if ($gfio->{position} > $length) {
        $gfio->{position} = $length;
    }

    # Update the size of the file
    $gfio->{size} = $length;

    return $gfio;
}

################################################################################

=head2 insert

    $gfio->insert($position, $data)

Inserts data into a file at a specified position.

Parameters:
- $position: The position in the file where the data should be inserted.
- $data: The data to be inserted into the file.

Returns:
- The GFIO object itself.

=cut

sub insert {
    my ($gfio, $position, $data) = @_;

    # Handle appending if specified
    if ($position eq 'append') {
        $gfio->seek($gfio->{size});
        $position = $gfio->{position};
    }

    # Ensure file is open for writing
    if (!$gfio->{opened}) {
        error("GFIO.Insert: File '$gfio->{file}' is closed");
    }

    # Check if file is writable
    if (!$gfio->{write} && !$gfio->{append}) {
        error("GFIO.Insert: File '$gfio->{file}' is write-protected");
    }

    # Calculate necessary movement length
    my $move_length = $gfio->{size} - $position;

    # Read data from current position to end of file
    my $data_to_move = $gfio->readptr($move_length);

    # Move file pointer to the insertion position and write new content
    $gfio->seek($position);
    $gfio->write($data);

    # Determine the new position after insertion and write back moved data
    my $new_position = $gfio->tell();
    $gfio->write($data_to_move);

    # Move file pointer to the new position after insertion
    $gfio->seek($new_position);

    return $gfio;
}

################################################################################

=head2 appenddata

    $gfio->appenddata($data)

Appends data to the end of a file.

Parameters:
- $data: The data to append to the end of the file.

Returns:
- The GFIO object itself.

=cut

sub appenddata {
    my ($gfio, $data) = @_;

    # Ensure file is open for writing
    if (!$gfio->{opened}) {
        error("GFIO.Appenddata: File '$gfio->{file}' is closed");
    }

    # Check if file is writable
    if (!$gfio->{write} && !$gfio->{append}) {
        error("GFIO.Appenddata: File '$gfio->{file}' is write-protected");
    }

    # Seek to the end of the file and write the data
    $gfio->seek($gfio->{size});
    $gfio->write($data);

    return $gfio;
}

################################################################################

=head2 extract

    $gfio->extract($length)

Extracts data from a file at the current position.

Parameters:
- $length: The length of data to extract from the current position.

Returns:
- The extracted data as a scalar.

=cut

sub extract {
    my ($gfio, $length) = @_;

    my $start = $gfio->{position};
    my $end = $gfio->{position} + $length;
    my $data;

    # Ensure file is open
    if (!$gfio->{opened}) {
        error("GFIO.Extract: File '$gfio->{file}' is closed");
    }

    # Extract data based on position and length
    if ($end > $gfio->{size}) {
        # If extraction length exceeds file size, read up to end of file
        $data = $gfio->readptr($gfio->{size} - $start);
        $gfio->truncate($start);
    } else {
        # Otherwise, read data, write back remaining file content,
        # truncate to new size, and reset position
        $gfio->seek($end);
        $data = $gfio->readptr($gfio->{size} - $end);
        $gfio->seek($start);
        $gfio->write($data);
        $gfio->truncate($gfio->{size} - $end);
        $gfio->seek($start);
    }

    return ${$data};
}

################################################################################

=head2 tell

    $gfio->tell()

Returns the current position in the file.

Returns:
- The current position in the file as an integer.

=cut

sub tell {
    my ($gfio) = @_;
    return $gfio->{position};
}

################################################################################

=head2 seek

    $gfio->seek($position)

Sets the position in the file.

Parameters:
- $position: The position to set within the file. Should be a non-negative integer.

Returns:
- The GFIO object itself after setting the new position.

=cut

sub seek {
    my ($gfio, $pos) = @_;

    # Check for negative position
    if ($pos < 0) {
        error("GFIO.Seek: Trying to seek before beginning of file '$gfio->{file}'", "Seek=$pos EOF=$gfio->{size}");
    }

    # Check if position is beyond end of file
    if ($pos > $gfio->{size}) {
        error("GFIO.Seek: Seek beyond end of file '$gfio->{file}'", "Seek=$pos EOF=$gfio->{size}");
    }

    # Perform seek operation and update current position
    sysseek($gfio->{handle}, $pos, 0);
    $gfio->{position} = $pos;

    return $gfio;
}

################################################################################

=head2 lock

    $gfio->lock()

Locks a file for exclusive access.

This function acquires an exclusive lock on the file associated with the GFIO object. 
If the file is already locked by this GFIO instance, it increments the lock count.

Returns:
- The GFIO object itself after acquiring the lock.

=cut

sub lock {
    my ($gfio) = @_;

    # Acquire exclusive lock if not already locked
    if (!$gfio->{locked}) {
        flock($gfio->{handle}, LOCK_EX);
    }

    # Increment the lock count
    $gfio->{locked}++;

    return $gfio;
}

################################################################################

=head2 unlock

    $gfio->unlock()

Unlocks a previously locked file.

This function releases the lock on the file associated with the GFIO object. If the lock
count drops to zero, it releases the exclusive lock.

Returns:
- The GFIO object itself after releasing the lock.

=cut

sub unlock {
    my ($gfio) = @_;

    # Check if the file is locked
    if ($gfio->{locked}) {
        $gfio->{locked}--;  # Decrease the lock count

        # Release the lock if no more locks are held
        if (!$gfio->{locked}) {
            flock($gfio->{handle}, LOCK_UN);
        }
    } else {
        error("GFIO.Unlock: File '$gfio->{file}' was not locked!");
    }

    return $gfio;
}

################################################################################

=head2 locked

    $gfio->locked()

Checks if the file associated with the GFIO object is currently locked.

Returns:
- The current lock count (0 if not locked, >0 if locked).

=cut

sub locked {
    my ($gfio) = @_;
    return $gfio->{locked};
}

################################################################################

=head2 content

    content($filename, $offset, $length)

Reads content from a file with specified offset and length.

Parameters:
- $filename: The name of the file to read content from.
- $offset: Optional. The starting position in bytes from where to begin reading. Default is 0.
- $length: Optional. The number of bytes to read from the file. Default is the entire file size.

Returns:
- The content read from the file as a scalar string.

=cut

sub content {
    my ($filename, $offset, $length) = @_;

    # Validate filename
    if (!$filename) {
        error("GFIO.Content: No filename given");
    }
    if (!-e $filename) {
        error("GFIO.Content: File '$filename' does not exist");
    }
    if (!-f $filename) {
        error("GFIO.Content: '$filename' is not a plain file");
    }

    # Open file handle and read content
    my $fh = gfio::open($filename, 'r');
    if (!defined $offset) { $offset = 0 }
    if (!defined $length) { $length = $fh->{size} }

    # Check offset and length boundaries
    if ($offset > $fh->{size}) {
        error("GFIO.Content: Read beyond boundaries of '$filename', offset=$offset, size=$fh->{size}");
    }
    if ($offset + $length > $fh->{size}) {
        error("GFIO.Content: Read beyond boundaries of '$filename', offset=$offset, reading $length bytes, size=$fh->{size}");
    }

    # Seek to the offset and read content
    $fh->seek($offset);
    my $txt = $fh->readptr($length);
    $fh->close;

    return ${$txt};
}

################################################################################

=head2 create

    create($filename, $content, $nonil, $mode)

Creates a new file with optional content and permissions.

Parameters:
- $filename: The name of the file to create.
- $content: Optional. The initial content to write into the file. Can be a scalar or a reference to a scalar.
- $nonil: Optional. If true, prevents creating the file if $content is undefined or an empty string.
- $mode: Optional. File permissions (mode) to set after creating the file, e.g., 0644.

=cut

sub create {
    my ($filename, $content, $nonil, $mode) = @_;

    # Validate filename
    if (!$filename) {
        return;  # Return early if no filename provided
    }

    # Prevent creation if $nonil is true and $content is nil or empty
    if ($nonil) {
        if (!defined $content || (ref($content) eq 'SCALAR' && length(${$content}) == 0) || (length($content) == 0)) {
            return;
        }
    }

    # Remove existing file if it exists and is a regular file
    if (-e $filename && -f $filename) {
        unlink($filename);
    }

    # Open file handle for writing
    my $fh = gfio::open($filename, 'w');

    # Write initial content if provided
    if (defined $content && length($content)) {
        if (ref($content) eq 'SCALAR') {
            $fh->write($content);
        } else {
            $fh->write(\$content);
        }
    }

    # Close file handle
    $fh->close;

    # Set file permissions if mode is provided
    if ($mode) {
        chmod($mode, $filename);
    }
}

################################################################################

=head2 newfile

    newfile($filename, $content, $noread)

Creates a new file and optionally writes content to it.

Parameters:
- $filename: The name of the file to create.
- $content: Optional. The initial content to write into the file. Can be a scalar or a reference to a scalar.
- $noread: Optional. If true, opens the file in write mode ('w') without read access.

Returns:
- A GFIO object representing the newly created file handle.

=cut

sub newfile {
    my ($filename, $content, $noread) = @_;

    # Validate filename
    if (!$filename) {
        return;  # Return early if no filename provided
    }

    # Determine mode based on $noread flag
    my $mode = $noread ? 'w' : 'rw';

    # Open file handle for writing (and reading if $noread is false)
    my $fh = gfio::open($filename, $mode);

    # Write initial content if provided
    if (defined $content && length($content)) {
        if (ref($content) eq 'SCALAR') {
            $fh->write($content);
        } else {
            $fh->write(\$content);
        }
    }

    return $fh;
}

################################################################################

=head2 append

    append($srcfile, $destfile)

Appends content from source file to destination file.

=cut

sub append {
  	my ($filename,$content) = @_;
  	if (!-e $filename) {
		error("GFIO.Append: File '$filename' does not exist")
  	}
  	my $fh=gfio::open($filename,'a'); 
  	if (ref($content) eq 'SCALAR') { $fh->write($content) } else { $fh->write(\$content) }
  	$fh->close
}

################################################################################

=head2 copy

    copy($src, $des, $nooverwrite)

Copies a file from source to destination.

Parameters:
- $src: The source file to copy.
- $des: The destination file to copy to.
- $nooverwrite: Optional. If true, prevents overwriting an existing destination file.

=cut

sub copy {
    my ($src, $des, $nooverwrite) = @_;

    # Check if source and destination are provided
    if (!$src || !$des) {
        return;  # Exit early if either source or destination is missing
    }

    # Check if source file exists
    if (!-e $src) {
        error("GFIO.Copy: Source file '$src' does not exist");
    }

    # Check if source is a file
    if (!-f $src) {
        error("GFIO.Copy: Source '$src' is not a file!");
    }

    # Check if destination file should not be overwritten
    if (!$nooverwrite || !-e $des) {
        # Remove existing destination file if it exists
        if (-e $des) {
            unlink $des;
        }

        # Open source and destination file handles
        my $source_fh = gfio::open($src, 'r');
        my $dest_fh   = gfio::open($des, 'w');

        my $eof = 0;
        my $buffer_size = 1 << 20;  # 1 MB buffer size
        my $position = 0;
        my $length = $source_fh->{size};

        # Copy data from source to destination
        while (!$eof) {
            # Adjust buffer size if remaining bytes to read are less than buffer size
            if ($position + $buffer_size > $length) {
                $buffer_size = $length - $position;
            }

            # Read from source and write to destination
            $dest_fh->write($source_fh->readptr($buffer_size));

            $position += $buffer_size;

            # Check if end of file reached
            if ($position >= $length) {
                $eof = 1;
            }
        }

        # Close file handles
        $source_fh->close;
        $dest_fh->close;
    }
}

################################################################################

=head2 changeowner

    changeowner($filename, $user, $group)

Changes the owner and group of a file.

Parameters:
- $filename: The name of the file whose owner and group are to be changed.
- $user: The new owner user name.
- $group: The new owner group name.

=cut

sub changeowner {
    if ($^O =~ /win/i) {
        return;  # Exit early if running on Windows
    }

    my ($filename, $user, $group) = @_;

    # Retrieve user and group IDs based on provided names
    my ($login, $pass, $uid, $gid) = getpwnam($user);
    my ($glogin, $gpass, $guid, $ggid) = getpwnam($group);

    # Change file owner and group if IDs are valid and filename is provided
    if ($uid && $ggid && $filename) {
        chown $uid, $ggid, $filename;
    }
}

################################################################################

=head2 makedir

    makedir($newdir, $mode)

Creates a directory and its parent directories if they do not exist.

Parameters:
- $newdir: The path of the directory to create.
- $mode: Optional. The permissions mode for the directory. Default is 0700.

=cut

sub makedir {
    my ($newdir, $mode) = @_;

    if (!$newdir) {
        return;  # Exit early if no directory path provided
    }

    if (!$mode) {
        $mode = 0700;  # Default mode if not specified
    }

    # Split directory path into components
    my @dir = split(/\//, $newdir);
    my $path = "";

    # Iterate over directory components and create directories as needed
    foreach my $d (@dir) {
        $path .= $d;

        # Skip creation if path is '.' or '..'
        if ($path && ($path ne '.') && ($path ne '..') && (!-e $path)) {
            mkdir($path, $mode) or die "Failed to create directory $path: $!";
        }

        $path .= "/";
    }
}

################################################################################

=head2 readdirs

    readdirs($dir, $subdirs, $verbose)

Recursively reads directory names.

Parameters:
- $dir: The directory path to start reading from.
- $subdirs: Flag to indicate whether to read subdirectories recursively.
- $verbose: Optional. Flag to enable verbose output.

Returns:
- A file handle object containing the directory information.

=cut

sub readdirs {
    my ($dir, $subdirs, $verbose) = @_;

    # Normalize directory path separators to '/'
    $dir =~ s/\\/\//g;

    # Initialize file handle object
    my $gfio = {};
    bless($gfio);
    $gfio->{dir} = $dir;
    $gfio->{exist} = 1;
    $gfio->{list} = [];
    $gfio->{recursive} = $subdirs;

    # Check if directory exists
    if (!-e $dir) {
        $gfio->{exist} = 0;
        return $gfio;
    }

    # Perform directory reading
    $gfio->doreaddirs($dir, 0, $verbose);

    # Clear verbose output if enabled
    if ($verbose) {
        print "\r";
        print " " x 79;
        print "\r";
    }

    return $gfio;
}

################################################################################

=head2 readfiles

    readfiles($dir, $extlist, $subdirs, $verbose)

Reads file names in a directory with filtering by extension.

Parameters:
- $dir: The directory path to read files from.
- $extlist: Comma-separated list of file extensions to filter by. Use '*' for all extensions.
- $subdirs: Flag to indicate whether to read files recursively from subdirectories.
- $verbose: Optional. Flag to enable verbose output.

Returns:
- A file handle object containing the file information.

=cut

sub readfiles {
    my ($dir, $extlist, $subdirs, $verbose) = @_;

    # Normalize directory path separators to '/'
    $dir =~ s/\\/\//g;

    # Initialize file handle object
    my $gfio = {};
    bless($gfio);
    $gfio->{dir} = $dir;
    $gfio->{exist} = 1;
    $gfio->{list} = [];
    $gfio->{recursive} = $subdirs;

    # Process extension list
    if (defined($extlist)) {
        $extlist =~ s/ //g;
        $gfio->{extlist} = {};
        foreach my $ext (split(/\,/, $extlist)) {
            $gfio->{extlist}{lc($ext)} = 1;
        }
    }

    # Check if directory exists
    if (!-e $dir) {
        $gfio->{exist} = 0;
        return $gfio;
    }

    # Set flag to include all extensions if extlist is not defined or '*'
    $gfio->{allext} = (!defined($extlist) || ($extlist eq '*') || !$extlist);

    my $num = 1;
    $gfio->doreadfiles($dir, $verbose, \$num);

    # Clear verbose output if enabled
    if ($verbose) {
        print "\r";
        print " " x 79;
        print "\r";
    }

    return $gfio;
}

################################################################################

=head2 doreadfiles

    $gfio->doreadfiles($dir, $verbose, $num)

Internal function for reading files in a directory.

Parameters:
- $dir: The directory path to read files from.
- $verbose: Optional. Flag to enable verbose output.
- $num: Reference to a scalar representing the current file number.

=cut

sub doreadfiles {
    my ($gfio, $dir, $verbose, $num) = @_;

    # Open directory handle
    my $handle;
    opendir($handle, $dir) or error("GFIO.Readfiles: Error opening directory '$dir': $!");

    # Determine if directory path ends with a slash
    my $slash = (substr($dir, length($dir) - 1, 1) eq '/');

    # Loop through directory contents
    do {
        my $fl;
        $fl = readdir($handle);

        # Exclude '.' and '..' directories
        if (defined $fl && ($fl ne ".") && ($fl ne '..')) {
            my @ss = split(/\//, $fl);
            my $fname = pop @ss;

            # Exclude specific system directories
            if ((lc($fname) ne 'system volume information') && (lc($fname) ne 'recycler')) {
                my @ps = split(/\./, $fname);
                my $fext = pop @ps;
                my $fsname;

                # Determine file name without extension
                if ($fname =~ /\./) {
                    $fsname = join(".", @ps);
                } else {
                    $fsname = $fext;
                    $fext = "";
                }

                # Construct full file path
                my $ff;
                if ($slash || !$dir) {
                    $ff = $dir . $fname;
                } else {
                    $ff = $dir . "/" . $fname;
                }

                # Process directory or readable file
                if ((!-l $ff) && (-r $ff)) {
                    if (-d $ff) {
                        # Recursive directory reading if enabled
                        if ($gfio->{recursive}) {
                            if ($verbose) {
                                $gfio->verbosefile("[$ff]");
                            }
                            $gfio->doreadfiles($ff, $verbose, $num);
                        }
                    } elsif ($gfio->{allext} || $gfio->{extlist}{lc($fext)}) {
                        # Include file if matches extension filter
                        if ($verbose) {
                            $gfio->verbosefile("${$num}. $fname");
                        }
                        ${$num}++;
                        my @data = ($fsname, $fext, $fname, $dir, $ff, 'file');
                        push @{$gfio->{list}}, \@data;
                    }
                }
            }
        }
    } until (!$fl);

    # Close directory handle
    closedir($handle);
}

################################################################################

=head2 doreaddirs

    $gfio->doreaddirs($dir, $lev, $verbose)

Internal function for reading directories recursively.

Parameters:
- $dir: The directory path to read directories from.
- $lev: The current recursion level (internal use).
- $verbose: Optional. Flag to enable verbose output.

=cut

sub doreaddirs {
    my ($gfio, $dir, $lev, $verbose) = @_;

    # Open directory handle
    my $handle;
    opendir($handle, $dir) or error("Error opening directory '$dir': $!");

    # Determine if directory path ends with a slash
    my $slash = (substr($dir, length($dir) - 1, 1) eq '/');

    # Loop through directory contents
    do {
        my $fl;
        $fl = readdir($handle);

        # Exclude '.' and '..' directories
        if (defined $fl && ($fl ne ".") && ($fl ne '..')) {
            my @ss = split(/\//, $fl);
            my $fname = pop @ss;

            # Exclude specific system directories
            if ((lc($fname) ne 'system volume information') && (lc($fname) ne 'recycler')) {
                my @ps = split(/\./, $fname);
                my $fext = pop @ps;
                my $fsname;

                # Determine file name without extension
                if ($fname =~ /\./) {
                    $fsname = join(".", @ps);
                } else {
                    $fsname = $fext;
                    $fext = "";
                }

                # Construct full directory path
                my $ff;
                if ($slash || !$dir) {
                    $ff = $dir . $fname;
                } else {
                    $ff = $dir . "/" . $fname;
                }

                # Process directory if readable and not a symbolic link
                if ((!-l $ff) && (-d $ff) && (-r $ff)) {
                    if ($verbose) {
                        $gfio->verbosefile("[$ff]");
                    }

                    # Create data structure for directory entry
                    my @data = ($fsname, $fext, $fname, $dir, $ff, $lev);
                    push @{$gfio->{list}}, \@data;

                    # Recursive traversal if enabled
                    if ($gfio->{recursive}) {
                        $gfio->doreaddirs($ff, $lev + 1, $verbose);
                    }
                }
            }
        }
    } until (!$fl);

    # Close directory handle
    closedir($handle);
}

################################################################################

=head2 dodirlist

    $gfio->dodirlist($dir, $lev)

Internal function for listing directories.

Parameters:
- $dir: The directory path to list directories from.
- $lev: The current recursion level (internal use).

=cut

sub dodirlist {
    my ($gfio, $dir, $lev) = @_;

    # Open directory handle
    my $handle;
    opendir($handle, $dir) or error("Error opening directory '$dir': $!");

    # Determine if directory path ends with a slash
    my $slash = (substr($dir, length($dir) - 1, 1) eq '/');

    # Loop through directory contents
    do {
        my $fl;
        $fl = readdir($handle);

        # Exclude '.' and '..' directories
        if (defined $fl && ($fl ne ".") && ($fl ne '..')) {
            my @ss = split(/\//, $fl);
            my $fname = pop @ss;

            # Split file name into base name and extension
            my @ps = split(/\./, $fname);
            my $fext = pop @ps;
            my $fsname;

            # Determine file name without extension
            if ($fname =~ /\./) {
                $fsname = join(".", @ps);
            } else {
                $fsname = $fext;
                $fext = "";
            }

            # Construct full directory path
            my $ff;
            if ($slash || !defined $dir) {
                $ff = $dir . $fname;
            } else {
                $ff = $dir . "/" . $fname;
            }

            # Process symbolic links
            if (-l $ff) {
                my @data = ($fsname, $fext, $fname, $dir, $ff);

                # Determine if link points to a directory or file
                if (-d $ff) {
                    push @data, '~dir', $lev;
                    push @{$gfio->{dirs}}, \@data;
                } elsif (-f $ff) {
                    push @data, '~file';
                    push @{$gfio->{files}}, \@data;
                }
            }
            # Process directories
            elsif (-d $ff) {
                my @data = ($fsname, $fext, $fname, $dir, $ff, 'dir', $lev);
                push @{$gfio->{dirs}}, \@data;

                # Recursively traverse subdirectories if enabled
                if ($gfio->{recursive}) {
                    $gfio->dodirlist($ff, $lev + 1);
                }
            }
            # Process regular files
            elsif (-f $ff) {
                my @data = ($fsname, $fext, $fname, $dir, $ff, 'file');
                push @{$gfio->{files}}, \@data;
            }
        }
    } until (!$fl);

    # Close directory handle
    closedir($handle);
}

################################################################################

=head2 chars

    chars($filename, $tabchr, $tabsize)

Processes characters in a file.

Parameters:
- $filename: The name of the file to process.
- $tabchr: Optional. The character to substitute for tabs (default: undef).
- $tabsize: Optional. The size of a tab character in spaces (default: 8).

Returns:
- An array reference containing lines from the file. Each line is represented as an array reference of characters.

=cut

sub chars {
    my ($filename, $tabchr, $tabsize) = @_;
    
    # Set default tab size if only $tabchr is provided
    if (defined $tabchr && !defined $tabsize) {
        $tabsize = 8;
    }
    
    my $lines = [];
    
    # Check if file exists
    if (!-e $filename) {
        return undef;
    }
    
    # Open file for reading
    open(my $fh, '<:encoding(UTF-8)', $filename) or die "Cannot open file '$filename' for reading: $!";
    
    # Process each line in the file
    while (<$fh>) {
        chomp $_;
        my @line = split(//, $_);  # Split line into characters
        
        if (defined $tabchr) {
            my $chars = [];
            my $i = 0;
            
            # Process each character in the line
            for my $c (@line) {
                if ($c eq "\t") {
                    # Handle tab character
                    my $tst = $i - (int($i / $tabsize) * $tabsize);
                    my $spaces = $tabsize - $tst;
                    $i += $spaces;
                    
                    # Substitute tab with $tabchr
                    for my $j (1..$spaces) {
                        push @$chars, $tabchr;
                    }
                } else {
                    # Regular character
                    $i++;
                    push @$chars, $c;
                }
            }
            push @$lines, $chars;  # Add processed line to $lines
        } else {
            # If $tabchr is not defined, just push the line as array reference
            push @$lines, \@line;
        }
    }
    
    close($fh);  # Close file handle
    
    return $lines;  # Return array reference of lines
}

################################################################################

=head2 lines

    lines($filename, $tabchr)

Processes lines in a file.

Parameters:
- $filename: The name of the file to process.
- $tabchr: Optional. Character to substitute for tabs. If defined, all tabs in lines will be replaced with this character.

Returns:
- An array reference where each element represents a line from the file. Each line is a string.

=cut

sub lines {
    my ($filename, $tabchr) = @_;

    my $lines = [];  # Array to store lines processed

    # Check if file exists
    if (!-e $filename) {
        return undef;
    }

    # Open file for reading
    open(my $fh, '<:encoding(UTF-8)', $filename) or die "Cannot open file '$filename' for reading: $!";

    # Process each line in the file
    while (<$fh>) {
        chomp $_;  # Remove newline character
        if (defined $tabchr) {
            $_ =~ s/\t/$tabchr/gs;  # Substitute tabs with specified character if $tabchr is defined
        }
        push @$lines, $_;  # Store processed line
    }

    close($fh);  # Close file handle

    return $lines;
}

################################################################################

=head2 makepath

    $gfio->makepath()

Creates directory path recursively for the file specified in the GFIO object.

Parameters:
- None.

Returns:
- None.

=cut

sub makepath {
    my ($gfio) = @_;

    my @dir = split(/\//, $gfio->{file});  # Split file path into directory components
    pop @dir;  # Remove the filename itself

    my $path = "";  # Initialize path variable

    foreach my $d (@dir) {
        $path .= $d;  # Append current directory component
        if ($path ne "" && $path ne '.' && $path ne '..' && !-e $path) {
            mkdir($path, 0700);  # Create directory if it doesn't exist
        }
        $path .= "/";  # Append directory separator for the next component
    }
}

################################################################################

=head2 verbosefile

    $gfio->verbosefile($txt)

Prints verbose information about file operations.

Parameters:
- $txt: Text message to print.

Returns:
- None.

=cut

sub verbosefile {
    my ($gfio, $txt) = @_;

    print "\rReading: ";  # Print "Reading: " on the same line
    if (length($txt) > 70) {
        print "...", substr($txt, length($txt) - 67);  # Print last 67 characters if $txt is longer than 70 characters
    } else {
        print $txt;  # Print $txt followed by spaces to align to 70 characters
        print " " x (70 - length($txt));
    }
}

############################ DIRECTORY LISTINGS ################################

=head2 dirlist

    dirlist($dir, $recursive)

Reads directories and files in a directory.

Parameters:
- $dir: Directory path to read.
- $recursive: Boolean flag indicating whether to read subdirectories recursively.

Returns:
- A hash reference containing directory and file information:
  {
    dir   => $dir,          # Directory path
    exist => 1 or 0,         # Existence indicator
    dirs  => \@directories,  # Array reference containing directory information
    files => \@files,        # Array reference containing file information
    recursive => $recursive  # Recursive flag
  }

=cut

sub dirlist {
    my ($dir, $recursive) = @_;
    $dir =~ s/\\/\//g;  # Normalize directory path by replacing backslashes with forward slashes

    my $gfio = {};  # Initialize a new hash reference
    bless($gfio);   # Bless the hash reference to make it an object

    $gfio->{dir} = $dir;          # Assign the directory path to the object
    $gfio->{exist} = 1;           # Set existence flag to true by default
    $gfio->{dirs} = [];           # Initialize an empty array for directories
    $gfio->{files} = [];          # Initialize an empty array for files
    $gfio->{recursive} = $recursive;  # Assign the recursive flag to the object

    if (!-e $dir) {  # Check if the directory exists
        $gfio->{exist} = 0;  # If not, set the existence flag to false
        return $gfio;        # Return the object with exist flag and empty lists for dirs and files
    }

    $gfio->dodirlist($dir, 0);  # Call internal method to populate directories and files

    return $gfio;  # Return the populated object
}

################################################################################

=head2 numfiles

    $gfio->numfiles()

Counts the number of files in the directory list.

Parameters:
- None.

Returns:
- Integer representing the number of files in the directory list.

=cut

sub numfiles {
    my ($gfio) = @_;
    return scalar(@{$gfio->{list}});  # Return the number of elements in the 'list' array reference
}

################################################################################

=head2 getfile

    $gfio->getfile($num)

Retrieves information about a specific file from the directory list.

Parameters:
- $num: Optional. Index of the file to retrieve (default is 1).

Returns:
- Hash reference containing detailed information about the file:
  - barename: Base name of the file without extension.
  - ext: File extension.
  - name: Full name of the file including extension.
  - dir: Directory path of the file.
  - fullname: Full path to the file.
  - level: Level or depth of the file (for directories).
  - mode: File mode/permissions.
  - size: Size of the file in bytes.
  - atime: Last access time of the file.
  - mtime: Last modification time of the file.
  - ctime: Creation time of the file.
  - isdir: Flag indicating if the entry represents a directory (1) or file (0).

=cut

sub getfile {
    my ($gfio, $num) = @_;
    if (!$num) { $num = 1 }  # Default to the first file if $num is not provided
    if (($num < 1) || ($num > $gfio->numfiles)) {
        error("GFIO.GetFile: File '$num' is invalid (must be between 1 and ".$gfio->numfiles.", reading '".$gfio->{dir}."')")
    }
    my $fi = $gfio->{list}[$num - 1];  # Get file information from the 'list' array
    my @stat = stat($fi->[4]) || (0)x11;  # Retrieve file statistics
    my $info = {
        barename => $fi->[0],
        ext => $fi->[1],
        name => $fi->[2],
        dir => $fi->[3],
        fullname => $fi->[4],
        level => $fi->[5],
        mode => $stat[2],
        size => $stat[7],
        atime => $stat[8],
        mtime => $stat[9],
        ctime => $stat[10]
    };
    $info->{isdir} = ($fi->[5] =~ /[0-9]/) ? 1 : 0;  # Determine if the entry is a directory
    return $info;
}

################################################################################

=head1 AUTHOR

(C) 2017 Chaosje, OnEhIppY, Domero, Groningen, NL

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

################################################################################
# EOF gfio.pm (C) 2017 Chaosje, OnEhIppY, Domero, Groningen, NL
