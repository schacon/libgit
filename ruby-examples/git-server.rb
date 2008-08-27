# Implements git-recieve-pack in ruby, so I can understand the damn thing
require 'socket'
require 'pp'
require 'zlib'
require 'fileutils'
require 'digest'
require 'objects'

class GitServer

  NULL_SHA = '0000000000000000000000000000000000000000'
  #CAPABILITIES = " report-status delete-refs "
  #CAPABILITIES = " multi_ack thin-pack side-band side-band-64k ofs-delta shallow no-progress "
  CAPABILITIES = " "
  
  OBJ_NONE = 0
  OBJ_COMMIT = 1
  OBJ_TREE = 2
  OBJ_BLOB = 3
  OBJ_TAG = 4
  OBJ_OFS_DELTA = 6
  OBJ_REF_DELTA = 7

  OBJ_TYPES = [nil, :commit, :tree, :blob, :tag, nil, :ofs_delta, :ref_delta].freeze

  def initialize(path)
    @path = path
  end
  
  def self.start_server(path)
    server = self.new(path)
    server.listen
  end

  def listen
    server = TCPServer.new('127.0.0.1', 9418)
    while (session = server.accept)
      t = GitServerThread.new(session, @path)
      t.do_action
      return
    end
  end

  class GitServerThread
  
    def initialize(session, path)
      @path = path
      @session = session
      @capabilities_sent = false
    end
  
    def do_action
      header_data = read_header
      case header_data[1]
      when 'git-receive-pack':
        receive_pack(header_data[2])
      when 'git-upload-pack':
        upload_pack(header_data[2])
      else
        @session.print 'error: wrong thingy'
      end
      @session.close
    end
  
    def receive_pack(path)
      @delta_list = {}
      
      @git_dir = File.join(@path, path)
      git_init(@git_dir) if !File.exists?(@git_dir)
      
      send_refs
      packet_flush
      read_refs
      read_pack
      write_refs
    end
    
    def write_refs
      @refs.each do |sha_old, sha_new, path|
        ref = File.join(@git_dir, path)
        FileUtils.mkdir_p(File.dirname(ref))
        File.open(ref, 'w+') { |f| f.write(sha_new) }
      end
    end
      
    def git_init(dir, bare = false)
      FileUtils.mkdir_p(dir) if !File.exists?(dir)
      
      FileUtils.cd(dir) do
        if(File.exists?('objects'))
          return false # already initialized
        else
          # initialize directory
          create_initial_config(bare)
          FileUtils.mkdir_p('refs/heads')
          FileUtils.mkdir_p('refs/tags')
          FileUtils.mkdir_p('objects/info')
          FileUtils.mkdir_p('objects/pack')
          FileUtils.mkdir_p('branches')
          add_file('description', 'Unnamed repository; edit this file to name it for gitweb.')
          add_file('HEAD', "ref: refs/heads/master\n")
          FileUtils.mkdir_p('hooks')
          FileUtils.cd('hooks') do
            add_file('applypatch-msg', '# add shell script and make executable to enable')
            add_file('post-commit', '# add shell script and make executable to enable')
            add_file('post-receive', '# add shell script and make executable to enable')
            add_file('post-update', '# add shell script and make executable to enable')
            add_file('pre-applypatch', '# add shell script and make executable to enable')
            add_file('pre-commit', '# add shell script and make executable to enable')
            add_file('pre-rebase', '# add shell script and make executable to enable')
            add_file('update', '# add shell script and make executable to enable')
          end
          FileUtils.mkdir_p('info')
          add_file('info/exclude', "# *.[oa]\n# *~")
        end
      end
    end
    
    def create_initial_config(bare = false)
      bare ? bare_status = 'true' : bare_status = 'false'
      config = "[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n\tbare = #{bare_status}\n\tlogallrefupdates = true"
      add_file('config', config)
    end
      
    def add_file(name, contents)
      File.open(name, 'w') do |f|
        f.write contents
      end
    end

    def read_refs
      @refs = []
      while(data = packet_read_line) do
        sha_old, sha_new, path = data.split(' ')
        @refs << [sha_old, sha_new, path]
      end
    end
  
    def read_pack
      (sig, ver, entries) = read_pack_header
      unpack_all(entries)
    end
  
    def unpack_all(entries)
      return if !entries
      1.upto(entries) do |number|
        unpack_object(number)
      end 
      puts 'checksum:' + @session.recv(20).unpack("H*")[0]
    end
  
    def unpack_object(number)
      c = @session.recv(1)[0]
      size = c & 0xf
      type = (c >> 4) & 7
      shift = 4
      while c & 0x80 != 0
        c = @session.recv(1)[0]
        size |= ((c & 0x7f) << shift)
        shift += 7
      end
          
      case type
      when OBJ_OFS_DELTA, OBJ_REF_DELTA
        sha = unpack_deltified(type, size)
        #puts "WRITE " + OBJ_TYPES[type].to_s + sha
        return
      when OBJ_COMMIT, OBJ_TREE, OBJ_BLOB, OBJ_TAG
        sha = unpack_compressed(type, size)
        #puts "WRITE " + OBJ_TYPES[type].to_s + sha   
        return
      else
        puts "invalid type #{type}"
      end
    end

    def unpack_compressed(type, size)
      object_data = get_data(size)
      sha = put_raw_object(object_data, OBJ_TYPES[type].to_s)
      check_delta(sha)
    end
    
    def check_delta(sha)
      unpack_delta_cached(sha) if @delta_list[sha]
      sha
    end
    
    def unpack_delta_cached(sha)
      base, type = get_raw_object(sha)
      @delta_list[sha].each do |patch|
        obj_data = patch_delta(base, patch)
        sha = put_raw_object(obj_data, type)
        check_delta(sha)
      end
      @delta_list[sha] = nil
    end

    def has_object?(sha1)
      File.exists?(File.join(@git_dir, 'objects', sha1[0...2], sha1[2..39]))
    end
    

    def get_raw_object(sha1)
      path = File.join(@git_dir, 'objects', sha1[0...2], sha1[2..39])
      return false if !File.exists?(path)
      buf = File.read(path)
      
      if buf.length < 2
        puts "object file too small"
      end

      if legacy_loose_object?(buf)
        content = Zlib::Inflate.inflate(buf)
        header, content = content.split(/\0/, 2)
        if !header || !content
          puts "invalid object header"
        end
        type, size = header.split(/ /, 2)
        if !%w(blob tree commit tag).include?(type) || size !~ /^\d+$/
          puts "invalid object header"
        end
        type = type.to_sym
        size = size.to_i
      else
        type, size, used = unpack_object_header_gently(buf)
        content = Zlib::Inflate.inflate(buf[used..-1])
      end
      puts "size mismatch" if content.length != size
      return [content, type]
    end
    
    def legacy_loose_object?(buf)
      word = (buf[0] << 8) + buf[1]
      buf[0] == 0x78 && word % 31 == 0
    end
    
    def unpack_object_header_gently(buf)
      used = 0
      c = buf[used]
      used += 1

      type = (c >> 4) & 7;
      size = c & 15;
      shift = 4;
      while c & 0x80 != 0
        if buf.length <= used
          raise LooseObjectError, "object file too short"
        end
        c = buf[used]
        used += 1

        size += (c & 0x7f) << shift
        shift += 7
      end
      type = OBJ_TYPES[type]
      if ![:blob, :tree, :commit, :tag].include?(type)
        raise LooseObjectError, "invalid loose object type"
      end
      return [type, size, used]
    end
    
    def put_raw_object(content, type)
      size = content.length.to_s

      header = "#{type} #{size}\0"
      store = header + content
                
      sha1 = Digest::SHA1.hexdigest(store)
      path = File.join(@git_dir, 'objects', sha1[0...2], sha1[2..40])
      
      if !File.exists?(path)
        content = Zlib::Deflate.deflate(store)
      
        FileUtils.mkdir_p(File.join(@git_dir, 'objects', sha1[0...2]))
        File.open(path, 'w') do |f|
          f.write content
        end
      end
      return sha1
    end
        
    def unpack_deltified(type, size)
      if type == OBJ_REF_DELTA
        base_sha = @session.recv(20)
        sha1 = base_sha.unpack("H*")[0]
        delta = get_data(size)
        if has_object?(sha1)
          base, type = get_raw_object(sha1)
          obj_data = patch_delta(base, delta)
          return put_raw_object(obj_data, type)
        else
          @delta_list[sha1] ||= []
          @delta_list[sha1] << delta
        end
      else
        i = 0
        c = data[i]
        base_offset = c & 0x7f
        while c & 0x80 != 0
          c = data[i += 1]
          base_offset += 1
          base_offset <<= 7
          base_offset |= c & 0x7f
        end
        offset += i + 1
        return false  ## NOT SUPPORTED YET ##
      end
      return nil
    end
  
    def get_data(size)
    	stream = Zlib::Inflate.new
      buf = ''
    	while(true) do
    	  buf += stream.inflate(@session.recv(1))
    		if (stream.total_out == size && stream.finished?)
    			break;
    		end
    	end
    	stream.close
    	buf
    end
  
    def patch_delta(base, delta)
      src_size, pos = patch_delta_header_size(delta, 0)
      if src_size != base.size
        raise PackFormatError, 'invalid delta data'
      end

      dest_size, pos = patch_delta_header_size(delta, pos)
      dest = ""
      while pos < delta.size
        c = delta[pos]
        pos += 1
        if c & 0x80 != 0
          pos -= 1
          cp_off = cp_size = 0
          cp_off = delta[pos += 1] if c & 0x01 != 0
          cp_off |= delta[pos += 1] << 8 if c & 0x02 != 0
          cp_off |= delta[pos += 1] << 16 if c & 0x04 != 0
          cp_off |= delta[pos += 1] << 24 if c & 0x08 != 0
          cp_size = delta[pos += 1] if c & 0x10 != 0
          cp_size |= delta[pos += 1] << 8 if c & 0x20 != 0
          cp_size |= delta[pos += 1] << 16 if c & 0x40 != 0
          cp_size = 0x10000 if cp_size == 0
          pos += 1
          dest += base[cp_off,cp_size]
        elsif c != 0
          dest += delta[pos,c]
          pos += c
        else
          raise PackFormatError, 'invalid delta data'
        end
      end
      dest
    end

    def patch_delta_header_size(delta, pos)
      size = 0
      shift = 0
      begin
        c = delta[pos]
        if c == nil
          raise PackFormatError, 'invalid delta header'
        end
        pos += 1
        size |= (c & 0x7f) << shift
        shift += 7
      end while c & 0x80 != 0
      [size, pos]
    end
  
    def read_pack_header
      sig = @session.recv(4)
      ver = @session.recv(4).unpack("N")[0]
      entries = @session.recv(4).unpack("N")[0]
      [sig, ver, entries]
    end
  
    def packet_read_line
      size = @session.recv(4)
      hsize = size.hex
      if hsize > 0
        @session.recv(hsize - 4)
      else
        false
      end
    end
  
    def packet_flush
      @session.send('0000', 0)
    end

    def send_ack
      @session.send("0007NAK", 0)
    end
  
    def refs
      @refs = []
      Dir.chdir(@git_dir) do
        Dir.glob("refs/**/*") do |file|
          @refs << [File.read(file), file] if File.file?(file)
        end
      end
      @refs
    end
  
    def send_refs
      refs.each do |ref|
        send_ref(ref[1], ref[0])
      end
      send_ref("capabilities^{}", NULL_SHA) if !@capabiliies_sent
    end
  
    def send_ref(path, sha)
      if (@capabilities_sent)
        packet = "%s %s\n" % [sha, path]
    	else
    		packet = "%s %s%c%s\n" % [sha, path, 0, CAPABILITIES]
    	end
    	write_server(packet)
    	@capabilities_sent = true
    end
    
    def write_server(data)
  		string = '000' + sprintf("%x", data.length + 4)
    	string = string[string.length - 4, 4]
    	
    	@session.send(string, 0)
    	@session.send(data, 0)
    end
  
    def upload_pack(path)
      @git_dir = File.join(@path, path)
      send_refs
      packet_flush
      receive_needs
      send_ack
      upload_pack_file
    end
    
    def receive_needs
      @need_refs = []
      while(data = packet_read_line) do
        cmd, sha = data.split(' ')
        @need_refs << [cmd, sha]
      end
      puts 'done:'
      puts @session.recv(9)
      @need_refs
    end
    
    def upload_pack_file
      @send_objects = {}
      @need_refs.each do |cmd, sha|
        if cmd == 'want' && sha != NULL_SHA
          @send_objects[sha] = ' commit'
          build_object_list_from_commit(sha)
        end
      end
      @send_objects = @send_objects.sort { |a, b| a[1] <=> b[1] }
      pp @send_objects

      build_pack_file
    end
    
    def build_pack_file
      @digest = Digest::SHA1.new
      
      # build_header
      write_pack('PACK')
      write_pack([2].pack("N"))
      write_pack([@send_objects.length].pack("N"))
      
      # build_pack
      @send_objects.each do |sha, name|
        # build pack header
        content, type = get_raw_object(sha)
        size = content.length
        btype = type_to_flag(type)
        
        c = (btype << 4) | (size & 15)
        c |= 0x80
      	size = (size >> 4)
      	write_pack(c.chr)
      	while (size > 0) do
      		c = size & 0x7f
        	size = (size >> 7)
        	if size > 0
      	    c |= 0x80;
      	  end
        	write_pack(c.chr)
      	end
      	
        # pack object data
        write_pack(Zlib::Deflate.deflate(content))
      end
      
      @session.send([@digest.hexdigest].pack("H*"), 0)
    end
    
    def type_to_flag(type)
      case type.to_s
      when 'commit': return OBJ_COMMIT
      when 'tree': return OBJ_TREE
      when 'blob': return OBJ_BLOB
      when 'tag': return OBJ_TAG
      end
    end
    
    def write_pack(bits)
      @session.send(bits, 0)
      @digest << bits
    end
    
    def object_from_sha(sha)
      content, type = get_raw_object(sha)
      Git::Object.from_raw(Git::RawObject.new(type.to_sym, content))
    end
    
    def build_object_list_from_commit(sha)
      # go through each parent sha
      commit = object_from_sha(sha)
      # traverse the tree and add all the tree/blob shas 
      @send_objects[commit.tree] = '/'
      build_object_list_from_tree(commit.tree)
      commit.parent.each do |p|
        @send_objects[p] = ' commit'
        build_object_list_from_commit(p)
      end
    end
    
    def build_object_list_from_tree(sha)
      tree = object_from_sha(sha)
      tree.entry.each do |t|
        @send_objects[t.sha1] = t.name
        if t.type == :tree
          build_object_list_from_tree(t.sha1)
        end
      end
    end
    
    def read_header()
      len = @session.recv( 4 ).hex
  		return false if (len == 0)
  		command, directory = read_until_null().strip.split(' ')
  		stuff = read_until_null()
  		# verify header length?
  		[len, command, directory, stuff]
  	end
	
  	def read_until_null(debug = false)
  	  data = ''
  	  while c = @session.recv(1)
  	    #puts "read: #{c}:#{c[0]}" if debug
  	    if c[0] == 0
  	      return data
  	    else
  	      data += c
  	    end
  		end
  		data
  	end
	
  
  end
end

#FileUtils.rm_r('/tmp/gittest') rescue nil
GitServer.start_server('/tmp/gittest')

