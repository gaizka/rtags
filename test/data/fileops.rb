# rtags regression test file (originally by David Powers as part of cfruby)

module Cfruby
	
	module FileOps
	
		# Class variable to control the behavior of FileOps.backup globally
		@@backup = true
	
		# Base class for all FileOperation specific exceptions
		class FileOpsError < Cfruby::CfrubyError
		end
		
		# Raised when the requested protocol for a file operation is unknown
		class FileOpsUnknownProtocolError < FileOpsError
		end
		
		# Raised when a file operation is attempted on a non-existent file
		class FileOpsFileExistError < FileOpsError
		end
		
		# Raised when a move or copy will overwrite a file and :force => false
		class FileOpsOverwriteError < FileOpsError
		end
		
		# Raised when a method is called on a file of the wrong type
		class FileOpsWrongFiletypeError < FileOpsError
		end
		
		# Interface description for FileCommand interface.  Should be
		# implemented on a case by case basis and included in the get_protocol
		# method. 
		class FileOps::FileCommand
			
			# Moves +filename+ to +newfilename+.  Options may be set to
			# one or more of the following:
			# <tt>:preserve</tt>:: true/false - preserve permissions
			# <tt>:noop</tt>:: true/false - don't actually do anything
			# <tt>:mode</tt>:: permissions - set the permissions of the copied file (uses chmod)
			def move(filename, newfilename, options={})
			end
			
			# Copies +filename+ to +newfilename+.  Options may be set to
			# one or more of the following:
			# <tt>:preserve:: true/false - preserve permissions
			# <tt>:noop:: true/false - don't actually do anything
			# <tt>:mode:: permissions - set the permissions of the copied file (uses chmod)
			def copy(filename, newfilename, options={})
			end
			
		end
		
		
		# FileCommand interface for local to local operations
		class FileOps::LocalFileCommand
			
			# Options:
			# <tt>:force</tt>:: (defaults to true) force the move
			# <tt>:mode</tt>:: set the mode of +newfilename+
			# <tt>:preserve</tt>:: attempts to preserve the mode and ownership of newfilename if it exists
			# <tt>:onlyonchange</tt>:: only copy if the file has changed (implies force)
			def move(filename, newfilename, options = {})
				if(options[:force] == nil)
					options[:force] = true
				end
				
				currentstat = nil
				Cfruby.controller.attempt("move #{filename} to #{newfilename}", 'destructive') {
					if(options[:onlyonchange] and File.exist?(newfilename))
						options[:force] = true
						originalsum = Cfruby::Checksum::Checksum.get_checksums(filename)
						newsum = Cfruby::Checksum::Checksum.get_checksums(newfilename)
						if(originalsum.sha1 == newsum.sha1)
							Cfruby.controller.attempt_abort("files have the same sha1 hash")
						end
					end

					if(File.exists?(newfilename))
						if(options[:preserve])
							currentstat = File.stat(newfilename)
						end

						if(options[:force])
							FileOps.delete(newfilename)
						else
							raise(FileOpsOverwriteError, "\"#{newfilename}\" already exists")
						end						
					end
					FileUtils.mv(filename, newfilename)
					
					if(currentstat and options[:preserve])
						FileOps.chmod(newfilename, currentstat.mode)
						FileOps.chown(newfilename, currentstat.uid, currentstat.gid)
					end
					
					if(options[:mode] != nil)
						FileOps.chmod(newfilename, options[:mode])
					end
				}
			end


			# Executes FileUtils.cp followed by FileOps.chmod and FileOps.chown (using :user, :group, and :mode).
			# If filename is a glob it will be expanded and all resultant filenames will be copied with the assumption
			# that newfilename is a directory.
			# Options:
			# <tt>:backup</tt>:: true to make a backup of +newfilename+ before copying
			# <tt>:force</tt>:: (defaults to true) force the copy even if newfilename exists
			# <tt>:onlyonchange</tt>:: only copy if the file has changed (implies force)
			# <tt>:recursive</tt>:: recursively copy 
			def copy(filename, newfilename, options = {})
				# set default options
				if(options[:force] == nil)
					options[:force] = true
				end
				if(options[:onlyonchange])
					options[:force] = true
				end
				
				# first, a basic check that filename exists somehow
				if(Dir.glob(filename).length == 0)
					raise(FileOpsFileExistError, "\"#{filename}\" does not exist")
				end

				# get the base directory of the copy
				basedir = File.dirname(Pathname.new(Dir.glob(filename)[0]).realpath.to_s)
				basedirregex = Regexp.new(Regexp.escape(basedir) + "/?(.*)$")
			
				# use file find to get a list of files to copy
				FileFind.find(filename, options) { |filename|
					# copy each file after adjusting for the base directories
					basename = basedirregex.match(filename)[1]
					if(File.directory?(newfilename))
						copy_single(filename, newfilename + "/#{basename}", options)
					else
						copy_single(filename, newfilename, options)
					end
				}
			end
			

			# Executes FileUtils.cp followed by FileOps.chmod and FileOps.chown (using :user, :group, and :mode).
			# filename and newfilename must be single files
			# Options:
			# <tt>:backup</tt>:: true to make a backup of +newfilename+ before copying
			# <tt>:force</tt>:: (defaults to true) force the copy even if newfilename exists
			# <tt>:onlyonchange</tt>:: only copy if the file has changed (implies force)
			def copy_single(filename, newfilename, options = {})
				mode	= options[:mode]
				owner = options[:user]
				group = options[:group]
				options.delete :mode
				options.delete :user
				options.delete :group

				force = options[:force]
				if(force == nil)
					force = true
				end
				
				Cfruby.controller.attempt("copy #{filename} to #{newfilename}", 'destructive') {
					if(!File.exists?(filename))
						raise(FileOpsFileExistError, "\"#{filename}\" does not exist")
					end
					if(!force and File.exists?(newfilename))
						raise(FileOpsOverwriteError, "\"#{newfilename}\" already exists")
					end
				
					if(options[:onlyonchange] and File.exist?(newfilename))
						options[:force] = true
						originalsum = Cfruby::Checksum::Checksum.get_checksums(filename)
						newsum = Cfruby::Checksum::Checksum.get_checksums(newfilename)
						if(originalsum.sha1 == newsum.sha1)
							Cfruby.controller.attempt_abort("files have the same sha1 hash")
						end
					end
				
					if options[:backup]
						FileOps.backup(newfilename) if File.exist? newfilename
						options.delete :backup
						options.delete :onlyonchange
					end
				
					if(File.exists?(newfilename) and force)
						FileOps.delete(newfilename)
					end
					
					if(File.directory?(filename))
						FileUtils.mkdir(newfilename)
					else
						FileUtils.cp(filename, newfilename, :preserve => true)
					end
				}
			
				# change ownership and mode if we need to
				FileOps.chown(newfilename,owner,group,options) if owner or group
				FileOps.chmod(newfilename,mode) if mode
			end
			
		end


		# FileCommand interface for rsync operations
		class FileOps::RsyncFileCommand

			# Options:
			# <tt>:user</tt>:: The user to use on the remote side
			# <tt>:archive</tt>:: Equivilant to -a in the rsync command
			# <tt>:recursive</tt>:: Recursive
			# <tt>:flags</tt>:: Passed directly to the rsync command
			def move(filename, newfilename, options = {})
			end


			# Options:
			# <tt>:archive</tt>:: Equivilant to -a in the rsync command
			# <tt>:recursive</tt>:: Recursive
			# <tt>:flags</tt>:: Passed directly to the rsync command
			def copy(filename, newfilename, options = {})
				flags = Array.new()
				if(options[:flags])
					flags << options[:flags]
				end
				
				if(options[:archive])
					flags << "-a"
				end
				
				if(options[:recursive])
					flags << "-r"
				end
				
				rsynccommand = "rsync #{flags.join(' ')} #{filename} #{newfilename}"
				Cfruby.controller.attempt(rsynccommand, 'destructive', 'unknown') {
					Cfruby::Exec.exec(rsynccommand)
				}
			end

		end
		

		# FileCommand interface for http operations
		class FileOps::HTTPFileCommand

			def move(filename, newfilename, options = {})
				raise(Exception, "HTTP move not implemented")
			end

			# Options:
			# <tt>:recursive</tt>:: Recursive
			# <tt>:flags</tt>:: Passed directly to the rsync command
			def copy(filename, targetdir, options = {})
				flags = Array.new()
				if(options[:flags])
					flags << options[:flags]
				end

				wgetcommand="cd #{targetdir} && "

				if(options[:recursive])
					wgetcommand=wgetcommand + "wget -q -np -nH -r -l inf --cut-dirs=#{filename.split(/\//).length} #{flags} http://#{filename}"
				else
					wgetcommand=wgetcommand + "wget -q #{flags} http://#{filename}"
				end

				Cfruby.controller.attempt(wgetcommand, 'destructive', 'unknown') {
					Cfruby::Exec.exec(wgetcommand)
				}
			end
		end


		# Returns a FileCommand object based on the first protocol it sees 
		# in either filename or newfilename
		def FileOps.get_protocol(filename, newfilename)
			protocolregex = /^([a-zA-Z]+):\/\//
			protocol = 'file'
			
			match = protocolregex.match(filename)
			if(match == nil)
				match = protocolregex.match(newfilename)
			end
			
			if(match != nil)
				protocol = match[1]
			end
			
			case(protocol)
				when 'file'
					return(LocalFileCommand.new())
				when 'rsync'
					return(RsyncFileCommand.new())
				when 'http'
					return(HTTPFileCommand.new())
				else
					raise(FileOpsUnknownProtocolError, "Unknown protocol - \"#{protocol}\"")
			end
		end
		
		
		# Moves +filename+ to +newfilename+.  Options may be set to
		# one or more of the following:
		# <tt>:??????</tt>:: anything defined under the protocol specific copy function
		def FileOps.move(filename, newfilename, options = {})
			get_protocol(filename, newfilename).move(strip_protocol(filename), strip_protocol(newfilename), options)
		end
		
		
		# Copies +filename+ to +newfilename+.  Options may be set to
		# one or more of the following:
		# <tt>:??????</tt>:: anything defined under the protocol specific copy function
		def FileOps.copy(filename, newfilename, options = {})
			get_protocol(filename, newfilename).copy(strip_protocol(filename), strip_protocol(newfilename), options)
		end


		# Create an empty file named +filename+
		# Returns true if the file was created, false otherwise
		def FileOps.touch(filename)
		  created = false
			Cfruby.controller.attempt("touch #{filename}") {
				if File.exist? filename
					# if the file already exists do nothing
					Cfruby.controller.attempt_abort("#{filename} already exists - won't create")
				else
					f = File.new(filename,File::CREAT|File::TRUNC|File::RDWR)
					f.close
					Cfruby.controller.inform('verbose', "created file #{filename}")
					created = true
				end
			}
			
			return(created)
		end


		# Alias for delete
		def FileOps.unlink(filenamelist)
			FileOps.delete(filenamelist)
		end
		

		# Creates a directory entry. +dirname+ can be an Array or String.
		# Options:
		# <tt>:mode</tt>:: mode of the directory
		# <tt>:user</tt>:: user to own the directory
		# <tt>:group</tt>:: group to own the directory
		# <tt>:makeparent</tt>:: make any needed parent directories
		# Returns true if a directory was created, false otherwise
		def FileOps.mkdir(dirname, options = {})
			if(dirname.kind_of?(String))
				dirname = Array.[](dirname)
			end

	created = false

			dirname.each { |d|
				Cfruby.controller.attempt("mkdir #{d}", 'destructive') {
					if(!File.directory?(d))
						if(options[:makeparent])
							FileUtils.mkdir_p(d)
						else
							FileUtils.mkdir(d)
						end
					  created = true
						mode = options[:mode]
						user = options[:user] or Process.euid()
						group = options[:group] or Process.egid()
						FileOps.chown(d,user,group,options)
						FileOps.chmod(d,mode) if mode
					else
						Cfruby.controller.attempt_abort("#{d} already exists")
					end
				}
			}
			
			return(created)
		end
	

		# Remove a directory entry. +dirname+ can be an Array or String.
		# Returns true if a directory was removed, false otherwise
		def FileOps.rmdir(dirname, force = false)
			if(dirname.kind_of?(String) or dirname.kind_of?(Pathname))
				dirname = Array.[](dirname)
			end

			deletedsomething = false
			dirname.each do | d |
				Cfruby.controller.attempt("rmdir #{d}", 'nonreversible', 'destructive') {
					if(!test(?e, d))
						Cfruby.controller.attempt_abort("#{d} does not exist")
					end
					if(test(?d, d))
						if(force)
							FileUtils.rm_rf(d)
							deletedsomething = true
						else
							FileUtils.rmdir(d)
							deletedsomething = true
						end
					else
						raise(FileOpsWrongFiletypeError, "\"#{d}\" is not a directory")
					end
				}
			end
			
			return(deletedsomething)
		end

		
		# Creates a symbolic link +linkfile+ which points to +filename+. 
		# If +linkfile+ already exists and it is a directory, creates a symbolic link
		# +linkfile/filename+. If +linkfile+ already exists and it is not a
		# directory, raises FileOpsOverwriteError.  Returns true if a link is made
		# false otherwise.
		# Options: 
		# <tt>:force</tt>:: if true, overwrite +linkfile+ even if it already exists
		def FileOps.link(filename, linkfile, options={})
		  createdlink = false
			if !File.exist? filename
				raise(FileOpsFileExistError, "filename '#{filename}' does not exist")
			else
				Cfruby.controller.attempt("link '#{linkfile}' -> '#{filename}'", 'destructive') {
					# Use a realpath for the filename - a relative path fails below
					filename = Pathname.new(filename).realpath
					if(File.exists?(linkfile))
						if(File.symlink?(linkfile) and Pathname.new(linkfile).realpath == filename)
							# if the link already exists do nothing
							Cfruby.controller.attempt_abort("#{linkfile} already exists as a symlink")
						elsif(options[:force])
							unlink(linkfile)
						else
							raise(FileOpsOverwriteError, "#{linkfile} already exists")
						end
					end
					
					FileUtils.ln_s(filename, linkfile)
					createdlink = true
				}
			end
			
			return(createdlink)
		end
		
		
		# Creates an empty file +filenames+ if the file does not already exist.	 +filenames+ may be
		# an Array or String.  If the file does exist, the mode and ownership may be adjusted.  Returns 
		# true if a file was created, false otherwise.
		def FileOps.create(filenames, owner = Process::Sys.geteuid(), group = Process::Sys.getegid(), mode = 0600)
			if(filenames.kind_of?(String))
				filenames = Array.[](filenames)
			end

	created = false
			filenames.each() { |filename|
				Cfruby.controller.attempt("create #{filename}", 'destructive') {
					currentumask = File.umask()
					begin
						if(!test(?f, filename))
							# set a umask that disables all access to the file by default
							File.umask(0777)
							File.open(filename, File::CREAT|File::WRONLY) { |fp| 
							}
							created = true
						end
						chmod = FileOps.chmod(filename, mode)
						chown = FileOps.chown(filename, owner, group)
						if(chmod == false and chown == false)
						  Cfruby.controller.attempt_abort("\"#{filename}\" exists and has the appropriate owner, group, and mode")
						else
						  created = true
					  end
					ensure
						# restore the umask
						File.umask(currentumask)
					end
				}
			}
			
			return(created)
		end
		

		# Lock a file +fn+, using a lockfile, and return a file handle to +fn+.
		# +attr+ are standard file open attributes like 'w'. File based locking is
		# used to correctly handle mounted NFS and SMB shares.
		def FileOps.flock(fn, attr=nil, ext='.cflock')
			Cfruby.controller.attempt("lock #{fn}") {
				begin
					fnlock = fn+ext
					if File.exist? fnlock
						Cfruby.controller.inform("warn", "File #{fn} is locked by #{fnlock} (remove to fix) - skipping!")
					end

					Cfruby.controller.inform('debug', "locking #{fnlock}")
					fl = File.open fnlock,'w'
					fl.print "pid=#{Process.pid}\nCfruby lock file"
					fl.close
					f = File.open fn, attr
					
					# ---- Update file
					yield f
				ensure
					Cfruby.controller.inform('debug', "unlock #{fnlock}")
					File.unlink fnlock if fl
					f.close if f
				end
			}
		end

		
		# Sets @@backup
		def FileOps.set_backup(newbackup)
			@@backup = newbackup
		end
		
		# Creates a backup copy of +filename+ with the new filename
		# filename_cfruby_yyyymmdd_x, where x increments as more backups
		# are added to the same directory.	Options:
		# <tt>:backupdir</tt>:: directory to hold the backups (defaults to the same directory as +filename+)
		# <tt>:onlyonchange</tt>:: prevent backup from making a backup if viable backup already exists.
		def FileOps.backup(filename, options={})
			if !@@backup
				return
			end
			
			Cfruby.controller.attempt("backup #{filename}", 'destructive') {
				if(!filename.respond_to?(:dirname))
					filename = Pathname.new(filename.to_s())
				end
				
				# set the backup directory if it wasn't passed in
				backupdir = options[:backupdir]
				if(backupdir == nil)
					backupdir = filename.dirname()
				end
				
				# find the latest backup file and test the current file against it
				# if :onlyonchange is true
				if(options[:onlyonchange])
					backupfiles = Dir.glob("#{backupdir}/#{filename.basename()}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9]*")
					if(backupfiles.length > 0)
						lastbackup = backupfiles.sort.reverse()[0]
						currentchecksums = Cfruby::Checksum::Checksum.get_checksums(filename)
						lastbackupchecksums = Cfruby::Checksum::Checksum.get_checksums(lastbackup)
						if(currentchecksums.sha1 == lastbackupchecksums.sha1)
							Cfruby.controller.attempt_abort("viable backup already exists \"#{lastbackup}\"")
						end
					end
				end
				
				tries = 3
				numbermatch = /_[0-9]{8}_([0-9]+)$/
				begin
					nextnum = -1
					
					# loop through any existing backup files to get the next number
					Dir.[]("#{backupdir}/#{filename.basename()}_#{Time.now.strftime('%Y%m%d')}_*") { |backupfile|
						match = numbermatch.match(backupfile)
						if(match != nil)
							if(match[1].to_i() > nextnum)
								nextnum = match[1].to_i()
							end
						end
					}
					nextnum = nextnum + 1
					
					# attempt to open it
					success = false
					begin
						File.open("#{backupdir}/#{filename.basename()}_#{Time.now.strftime('%Y%m%d')}_#{nextnum}", File::RDONLY)
					rescue Exception
						FileOps.copy(filename, "#{backupdir}/#{filename.basename()}_#{Time.now.strftime('%Y%m%d')}_#{nextnum}")
						success = true
					end
					
					if(false == success)
						raise(Exception, "Unable to create backup copy of #{filename}")
					end
				rescue Exception
					# we play this game three times just to try to handle possible race
					# conditions between the choice of filename and the opening of the file
					tries = tries - 1
					if(tries < 0)
						raise($!)
					end
				end
			}
		end
		
		
		# Deletes files that contain no alphanumeric characters.  Returns true if any files were deleted
		# false otherwise
		def FileOps.delete_nonalpha(basedir, options = {})
		  deleted = false
			Cfruby.controller.attempt("deleting files non-alpha files from \"#{basedir}\"", 'nonreversible', 'destructive') {
				if(FileOps.delete_not_matching_regex(basedir, /[a-zA-Z0-9]/))
				  deleted = true
			  end
			}
			
			return(deleted)
		end


		# Deletes matching files.  Returns true if a file is actually deleted, false otherwise.
		# In addition to the normal find options delete also takes:
		# <tt>:force</tt>:: => (true|false) delete non-empty matching directories
		def FileOps.delete(basedir, options = {})
			deletedsomething = false
			Cfruby.controller.attempt("deleting files from \"#{basedir}\"", 'nonreversible', 'destructive') {
				begin
					options[:returnorder] = 'delete'
					Cfruby::FileFind.find(basedir, options) { |filename|
						if(!filename.symlink?() and filename.directory?())
							FileOps.rmdir(filename, options[:force])
						else
							FileOps::SymlinkHandler.unlink(filename)
						end
						deletedsomething = true
					}
				rescue Cfruby::FileFind::FileExistError
					Cfruby.controller.attempt_abort("#{basedir} does not exist")
				end
			}
			
			return(deletedsomething)
		end


		# Changes the owner, group, and mode all at once.  Returns true if a change was made to
		# owner, group, or mode - false otherwise. If mode==nil it is ignored.
		def FileOps.chown_mod(basedir, owner, group, mode, options = {})
		  changemade = false
			Cfruby.controller.attempt("changing ownership and mode of matching files in \"#{basedir}\"", 'destructive') {
				usermanager = Cfruby::OS::OSFactory.new.get_os.get_user_manager()
				if(owner and !owner.kind_of?(Integer))
					owner = usermanager.get_uid(owner)
				end
				if(group and !group.kind_of?(Integer))
					group = usermanager.get_gid(group)
				end

				Cfruby::FileFind.find(basedir, options) { |filename|
					if(FileOps.chown(filename, owner, group))
					  changemade = true
				  end
					if(mode!=nil and FileOps.chmod(filename, mode))
					  changemade = true
				  end
				}
			}
			
			return(changemade)
		end


		# Disables matching files by setting all permissions to 0000.  Returns true if anything
		# was disabled, false otherwise.
		def FileOps.disable(basedir, options = {})
		  disabled = false
			Cfruby.controller.attempt("disabling file in \"#{basedir}\"", 'destructive') {
				Cfruby::FileFind.find(basedir, options) { |filename|
					if(Cfruby::FileOps.chmod(filename, 0000))
					  disabled = true
				  end
				}
			}
			
			return(disabled)
		end


		# Chown's matching files.  Returns true if a change was made, false otherwise.
		def FileOps.chown(basedir, owner, group=nil, options = {})
		  changemade = false
			usermanager = Cfruby::OS::OSFactory.new.get_os.get_user_manager()
			if(owner and !owner.kind_of?(Integer))
				owner = usermanager.get_uid(owner)
			end
			if(group and !group.kind_of?(Integer))
				group = usermanager.get_gid(group)
			end

			Cfruby::FileFind.find(basedir, options) { |filename|
				Cfruby.controller.attempt("changing ownership of \"#{filename}\" to \"#{owner}:#{group}\"", 'destructive') {
					currentuid = File.stat(filename).uid
					currentgid = File.stat(filename).gid
					filename.chown(owner, group)
					if(currentuid == File.stat(filename).uid and currentgid == File.stat(filename).gid)
						Cfruby.controller.attempt_abort("unchanged, already owned by \"#{owner}:#{group}\"")
					end
					changemade = true
				}
			}
			
			return(changemade)
		end


		# Chmod's matching files.  Returns true if a change was made, false otherwise.
		def FileOps.chmod(basedir, permissions, options = {})
		  changemade = false
		  
			Cfruby::FileFind.find(basedir, options) { |filename|
				attemptmessage = "changing permissions of \"#{filename}\" to \""
				if(permissions.kind_of?(Numeric))
					attemptmessage = attemptmessage + sprintf("%o\"", permissions)
				else
					attemptmessage = attemptmessage + "#{permissions}\""
				end
				Cfruby.controller.attempt(attemptmessage, 'destructive') {
					currentmode = File.stat(filename).mode()
					# try it with internal functions, but try to call chmod if we have to
					if(permissions.kind_of?(Numeric))
						FileUtils.chmod(permissions, filename)
					else
						output = Cfruby::Exec.exec("chmod '" + permissions.to_s.gsub(/'/, "\\\&") + "' '" + filename.realpath.to_s.gsub(/'/, "\\\&") + "'")
						if(output[1].length > 0)
							raise(FileOpsError, output.join("\n"))
						end
					end
					
					if(currentmode == File.stat(filename).mode())
						Cfruby.controller.attempt_abort("unchanged, already set to \"#{permissions}\"")
					else
					  changemade = true
					end
				}
			}
			
			return(changemade)
		end
				

		# Methods for standard operations involving symbolic links
		module FileOps::SymlinkHandler

			# Returns File.stat unless it is a symbolic link not pointing
			# to an existing file - in that case it returns File.lstat
			def SymlinkHandler.stat(filename)
			  if(!filename.kind_of?(Pathname))
			    filename = Pathname.new(filename.to_s)
		    end

				if(filename.symlink? and broken?(filename))
					return File.lstat(filename)
				end
				
				return(File.stat(filename))
			end

			# the stdlib Pathname.unlink balks when removing a symlink -
			# this method will call File.unlink instead when dealing with
			# a symlink
			def SymlinkHandler.unlink(filename)
			  if(!filename.kind_of?(Pathname))
			    filename = Pathname.new(filename.to_s)
		    end

				if filename.symlink?()
					File.unlink filename.expand_path
				else
					filename.unlink()
				end
			end
			
			# Returns true if a file is a broken symlink
			def SymlinkHandler.broken?(symlink)
			  if(!symlink.kind_of?(Pathname))
			    symlink = Pathname.new(symlink.to_s)
		    end
		    
		    if(!symlink.symlink?())
			return(false)
		end
		    
		    # expand the path and catch the ensuing error in the case of a broken link
		    begin
			symlink.realpath()
		rescue
		  if($!.kind_of?(Errno::ENOENT) and $!.to_s =~ /^no such file/i)
		    return(true)
	    else
		raise($!)
	    end
	  end
	  
	  return(false)
		  end

			# Returns whether a symlink is actually pointing to +filename+.
			# Both parameters may be strings or File objects. This method
			# is used by Cfenjin to ascertain that when a symlink exists it
			# points to the right file. It returns false when +filename+
			# does not exist (i.e. symlink points to nothing).
			#
			# In the case the symlink does not exist a FileOpsWrongFiletypeError
			# is thrown.
			def SymlinkHandler.points_to?(symlink, filename)
			  if(!filename.kind_of?(Pathname))
			    filename = Pathname.new(filename.to_s)
				end

			  if(!symlink.kind_of?(Pathname))
			    symlink = Pathname.new(symlink.to_s)
				end

				return false if !filename.exist? 
				raise FileOpsWrongFiletypeError if !symlink.symlink?

				return filename.realpath.to_s == symlink.realpath.to_s
			end

		end
		
				
		private

		def FileOps.strip_protocol(filename)
			return(filename.to_s[/^([a-zA-Z]+:\/\/)?(.*)$/,2])
		end

	end
	
end
