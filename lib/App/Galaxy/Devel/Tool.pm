package App::Galaxy::Devel::Tool;
# ABSTRACT: App::Galaxy::Devel::Tool - build and deploy Perl tools on galaxy 

#Core Modules
use strict;
use warnings;
use autodie;
use Carp;

##cpan modules
use Any::Moose;
# executing system commands
use IPC::System::Simple qw(system);
#exception handling
use Try::Tiny;
#file manip
use File::chdir;
use File::Spec::Functions; #exports: catdir,canonpath,catdir,catfile,curdir,rootdir,updir,no_upwards,file_name_is_absolute,path
use Path::Class;  #might be able to replace file::spec::functions with path::class 
use File::Path qw(make_path);
use File::HomeDir;
use File::Find::Rule;
use File::stat;
use IO::All;
#other
use Config::Tiny; # accessing dzil and creating own config files
use Template::Tiny; 
use HTTP::Tiny;   # restarting galaxy
use Archive::Tar; 

has 'ssh_opts' => ( isa => 'HashRef', is => 'rw', lazy_build =>1);
has 'host' =>  ( isa => 'Str|Undef', is => 'rw', lazy_build => 1 ); # don't require
has 'key_path' => ( isa => 'Str|Undef', is => 'rw', lazy_build => 1 ); #don't require
has 'dist_name'  => ( isa => 'Str', is => 'rw', lazy_build => 1 );
has 'dist_name_prefix' => ( isa => 'Str', is => 'rw', lazy_build => 1); 
has 'dist_name_suffix' => ( isa => 'Str', is => 'rw', lazy_build =>1); #don't require
has 'dist_build_name'  => ( isa => 'Str', is => 'rw', lazy_build => 1);
has 'dist_build_name_archive' => ( isa => 'Str', is => 'rw', lazy_build => 1);
has 'dzil_config' => (isa => 'Config::Tiny', is =>'rw', lazy_build => 1 );
has 'full_path'   => ( isa => 'Str', is => 'rw');
has 'custom_tool_dir' => ( isa => 'Str', is => 'rw', default => sub { return "myTools" } );
has 'gxy_tool_dir' => ( isa => 'Str', is => 'rw', default => sub { return "/mnt/galaxyTools/galaxy-central/tools" } );
has 'gxy_central_dir' => ( isa => 'Str', is => 'rw', default => sub { return "/mnt/galaxyTools/galaxy-central" } );
has 'tool_conf_name' => (isa => 'Str', is => 'rw', default => sub { return "tool_conf.xml" } );
has 'template_cfg' => ( isa => 'Str', is => 'rw', lazy_build => 1 );
has 'template_bin' => ( isa => 'Str', is => 'rw', lazy_build => 1 );
has 'template_cmd_simple' => ( isa => 'Str', is => 'rw', lazy_build => 1 );
has 'template_bin_cmd_simple' => ( isa => 'Str', is => 'rw', lazy_build => 1 );
has 'template_bin_ui_cfg_tool' => ( isa => 'Str', is => 'rw', lazy_build => 1 );
has 'template_test_cmd_simple' => ( isa => 'Str', is => 'rw', lazy_build => 1 );
has 'template_td_fasta_file' => ( isa => 'Str', is => 'rw', lazy_build => 1);
has 'user'  => ( isa => 'Str', is => 'rw', default => sub {return "ubuntu"} );
has 'local_config_dirname' => (isa => 'Str', is => 'rw', default => sub { ".galaxy" } ) ;
has 'local_config_filename' => (isa => 'Str', is => 'rw', default => sub { ".galaxp" } ) ;
has 'local_config_file_path'=> ( isa => 'Str', is => 'rw', lazy_build =>1 );  
has 'local_config_basename'=> ( isa => 'Str', is => 'rw', default => sub { return File::HomeDir->my_data  } );
has 'local_config_setup_filename'=>   (isa => 'Str', is => 'rw', default => sub { "setup.yaml" } ) ; 
has 'local_config_setup_file_path'=> ( isa => 'Str', is => 'rw', lazy_build =>1 );  
has 'remote_cpanm_log' => (isa => 'Str', is => 'rw', default => sub { return "/home/ubuntu/.cpanm/build.log" }); #/home/galaxy/.cpanm/build.log
has 'remote_universal_wsgi_path' => ( isa => 'Str', is => 'rw', default => sub {'/mnt/galaxyTools/galaxy-central/universe_wsgi.ini'});

with 'App::Galaxy::Devel::Tool::Role::SSH';

sub _build_key_path {
    my $self = shift;   
    # if config file is there, then return value for key...  
    stat( $self->local_config_file_path ) ?  ( return Config::Tiny->read( $self->local_config_file_path )->{_}->{key} ) : return undef;    
}

sub _build_host {
    my $self = shift;
    stat( $self->local_config_file_path ) ?  ( return Config::Tiny->read( $self->local_config_file_path )->{_}->{host} ) : return undef;
}

sub _build_local_config_file_path {
    my $self = shift;
    return catdir( $self->local_config_basename, $self->local_config_dirname, $self->local_config_filename); 
}

sub _build_local_config_setup_file_path {
    my $self = shift;
    return catdir( $self->local_config_basename, $self->local_config_dirname, $self->local_config_setup_filename); 
}

sub _build_ssh_opts {
    my $self = shift;
    croak "Need to set key_path" unless defined( $self->key_path );
    return { key_path => $self->key_path, strict_mode => 0, user => $self->user }; 
}

sub _build_dist_name_suffix {
    my $self = shift;
    
    if ( defined ( $self->dist_name ) ) {     
      return $self->dist_name_suffix_from_dist_name(  $self->dist_name );
    } else {
      return undef;        
    }
}

sub _build_dist_name_prefix {
    my $self = shift;
    return "GalaxyX-Tool";
}

sub _build_dist_name {
    my $self = shift;     
    croak "Need to set dist_name_suffix" unless defined($self->dist_name_suffix);
    return $self->dist_name_prefix .'-'. $self->dist_name_suffix;
}

sub _build_dzil_config {
    my $self = shift;
    my $cf = Config::Tiny->new;
    $cf->read( catdir( $CWD,'dist.ini' ) )  or croak "Couldn't read dist.ini at ", catdir( $CWD,'dist.ini' ), $cf->errstr; 
}

sub _build_dist_build_name {
    my $self = shift;     
    my $version = $self->dzil_config->{_}->{version}; 
    my $name = $self->dzil_config->{_}->{name};
    return $name.'-'.$version;
}

sub _build_dist_build_name_archive {
    my $self = shift;     
    my $version = $self->dzil_config->{_}->{version}; 
    my $name = $self->dzil_config->{_}->{name};
    return $name.'-'.$version.'.tar.gz';
}

sub _build_ssh {
    my $self = shift;
    croak "Need to set host" unless defined( $self->host );
    my $ssh = Net::OpenSSH->new( $self->host, %{ $self->ssh_opts } );
    $ssh->error and croak "Couldn't establish SSH connection: ". $ssh->error;
    return $ssh;
}

sub build_dzil {
    my ($self, $arg) = @_;   
    system( "dzil build $arg" ) and croak "Build failed"; 
}

sub archive_local_dist {
    my $self = shift;
    # Get files
    my @filelist = File::Find::Rule->file->in( $self->dist_build_name );
    croak "Error: ", Archive::Tar->error unless 
      Archive::Tar->create_archive( $self->dist_build_name_archive, COMPRESS_GZIP, @filelist ); 
}

sub send_remote {
    my $self = shift;
    my $file = shift;
    $file ||= $self->dist_build_name_archive; 
}

sub install_remote {
    my $self = shift;    
    my $cmd = "sudo cpanm " .catdir("/tmp", $self->dist_build_name_archive) . " 2>&1 1>/dev/null 0>/dev/null &" ;
}

sub install_module_remote {
    my $self = shift;
    my $module_str = shift;
    my $cmd = "sudo cpanm " . $module_str . " 2>&1 1>/dev/null 0>/dev/null &";
}

sub extract_in_tmp {
   
    my $self = shift;
    my $folder = shift; #e.g bin cfg
    croak "no folder defined in extract_in_tmp" unless defined($folder);
    
    my $cmd =
    "cd /tmp;" 
        ."sudo -u galaxy tar -xmvf "
        . catdir( $self->dist_build_name_archive)
        . " "  
        . catdir( $self->dist_build_name, $folder );
}

sub check_custom_tool_dir_exists {
    my $self = shift;
    my $cmd = 'stat -t ' . catdir( $self->gxy_tool_dir, $self->custom_tool_dir );    
}

sub create_custom_tool_dir {
    my $self = shift;
    my $cmd = 'sudo -u galaxy mkdir ' . catdir( $self->gxy_tool_dir, $self->custom_tool_dir );    
}

sub copy_to_custom_tool_dir {
    my $self = shift;
    my $folder = shift;
    my $custom_tool_dir = shift;
    $self->custom_tool_dir($custom_tool_dir) if defined( $custom_tool_dir); #otherwise defaults to myTools
    
    my $cmd = 
      "sudo -u galaxy cp " . 
      catdir( "/tmp", $self->dist_build_name, $folder, "*") . 
      " " . 
      catdir( $self->gxy_tool_dir, $self->custom_tool_dir );   
}

sub new_section_tool_conf {
    my $self = shift;
    my $custom_tool_dir = $self->custom_tool_dir;
    my $id = 'id'.ucfirst($custom_tool_dir);
    my $tool_cfg_path = catdir( $self->gxy_central_dir, $self->tool_conf_name);
    
    my $cmd = 
    qq{
     sudo -u galaxy sed -i'.bk.sec' '/<\\/toolbox>/ i\\    <section name="$custom_tool_dir" id="$id">\\n    <\\/section>' $tool_cfg_path        
    } ;
}

sub update_section_tool_conf {
    my $self = shift;
    my $custom_tool_dir = $self->custom_tool_dir;
    my $id = 'id'.ucfirst($custom_tool_dir); #'mTools';
    my $tool_cfg_path = catdir( $self->gxy_central_dir, $self->tool_conf_name);
    my $toolcfg = $self->dist_name_suffix . '.xml';
    my $cmd = 
    qq{
     sudo -u galaxy sed -i'.bk.tool' '/<section name="$custom_tool_dir" id="$id">/ a\\    <tool file="$custom_tool_dir/$toolcfg" id="$id"\\/>' $tool_cfg_path
    };

}

sub  section_exists_tool_conf {
    my $self = shift;
    # do a grep of the file
    my $custom_tool_dir = $self->custom_tool_dir;
    my $id = 'id'.ucfirst($custom_tool_dir);
    my $tool_cfg_path = catdir( $self->gxy_central_dir, $self->tool_conf_name);
    my $cmd = qq{
       grep '<section name="$custom_tool_dir" id="$id">' $tool_cfg_path    
    } ;
}


sub  section_tool_grep_tool_conf {
    my $self = shift;
    my $custom_tool_dir = $self->custom_tool_dir;
    my $id = 'id'.ucfirst($custom_tool_dir);
    my $tool_cfg_path = catdir( $self->gxy_central_dir, $self->tool_conf_name);
    my $toolcfg = $self->dist_name_suffix . '.xml';
    # grep of the file
    my $cmd = qq{grep  '<tool file="$custom_tool_dir/$toolcfg" id="$id"/>'  $tool_cfg_path} ;
}

sub add_admin {
    my $self = shift;
    my $users_ref = shift;
    my $universe_wsgi_path = $self->remote_universal_wsgi_path;
   
   my $users = join " ", @$users_ref;
   $users = " ".$users;
   $users =~ s/@/\\@/g;
   my $cmd = qq{sudo -u galaxy perl -Mautobox::Core -i.bak -pe 'if(/^#admin_users/){ my \$str = "admin_users = $users\\n"; s/\$\_/\$str/; } if( /^admin_users = (.+)/){ my \$str = \$1->concat( "$users" )->split(" ")->uniq->join(" ")->concat("\\n"); \$str = "admin_users = \$str"; s/\$\_/\$str/;  }' $universe_wsgi_path};
}

# If dzil is not already configured
# then this will be used to create
# that config
sub make_dzil_config {
    my $self = shift;
    make_path( catdir( File::HomeDir->my_home, '.dzil') );
    my $str = 
    '[%User]
name  = You
email = you@example.com

[%Rights]
license_class    = Perl_5
copyright_holder = You
';
    $str > io(catdir( File::HomeDir->my_home, '.dzil', 'config.ini'));

}


sub mint_dzil {
    my $self = shift;

    my $dist_name = $self->dist_name;
    #croak "No name for distribution" unless defined($name);
    $self->make_dzil_config unless stat( catdir( File::HomeDir->my_home, '.dzil', 'config.ini'));
    system( "dzil new $dist_name") and croak "Failed to initialise distribution with dzil new";
    
    try {
      make_path( catdir( $self->dist_name, "bin" ) ); 
      make_path( catdir( $self->dist_name, "t" ) );
      make_path( catdir( $self->dist_name, "td" ) );
      make_path( catdir( $self->dist_name, "cfg" ) );
      # this takes account of stuff like
      # making a module GalaxyX-Tool-Name1-Name2
      my @name = split ('-', $self->dist_name_suffix );
      $name[-1] .= '.pm';
      my $io = io( catdir($self->dist_name,'lib','GalaxyX','Tool', @name )  );
      $io->[3] = "use Moose;";
      $io->[4] = "#ABSTRACT: This does something\n";
      $io->[5] = "1;";
           
      $self->append_prereq_dzil;
    }
    catch {
      print "Error making distribution: $_";        
    };
}

sub make_app_cmd_skeleton {
    my $self = shift;
    try {
        my @path = File::Find::Rule->file()->name('*.pm')->in( $self->dist_name );
        my $f = file($path[0]);
        make_path( catdir( $f->parent, $self->dist_name_suffix ) );
        $self->template_cmd_simple > io( catdir( $f->parent, $self->dist_name_suffix, 'Cmd.pm' ) ) ; 
    } catch {
      print "Error making App Cmd Skeleton: $_";        
    }
}

sub append_prereq_dzil {
    my $self = shift; 
    my $dist_ini_path =  catdir( $self->dist_name,'dist.ini' ) ;   
    my $dist_ini < io( $dist_ini_path);    
    "[AutoPrereqs]
    skip = FindBin::libs
    skip = Galaxy::Devel::UI::Builder
    " >> io( $dist_ini_path ) unless ( $dist_ini =~ /\[AutoPrereqs\]/) ; 
}


sub make_bin_cfg_skeleton {
    my $self = shift;
    my $app_simple = shift;
     # create xml file
    $self->template_cfg > io( catdir($self->dist_name, "cfg", $self->dist_name_suffix . ".xml" ) );
    $self->template_bin_ui_cfg_tool > io( catdir($self->dist_name, "bin", $self->dist_name_suffix . "-cfg.pl" ) );
    $self->template_td_fasta_file >  io( catdir($self->dist_name, "td", $self->dist_name_suffix . "-test.fasta" ) );
    if( defined( $app_simple ) ) { 
      $self->template_bin_cmd_simple > io( catdir($self->dist_name, "bin", $self->dist_name_suffix . ".pl" ) );
      $self->template_test_cmd_simple > io( catdir($self->dist_name, "t", '001_'.$self->dist_name_suffix . ".t" ) );
    } else {
      $self->template_bin > io( catdir($self->dist_name, "bin", $self->dist_name_suffix . ".pl" ) );
    }
}

sub _build_template_cfg {
    my $self = shift;
    my $input = '<tool id="fa_gc_content_1" name="Compute GC content">
  <description>for each sequence in a file</description>
  <command interpreter="perl">[% name %] $input $output</command>
  <inputs>
    <param format="fasta" name="input" type="data" label="Source file"/>
  </inputs>
  <outputs>
    <data format="tabular" name="output" />
  </outputs>

  <tests>
    <test>
      <param name="input" value="fa_gc_content_input.fa"/>
      <output name="out_file1" file="fa_gc_content_output.txt"/>
    </test>
  </tests>

  <help>
This tool computes GC content from a FASTA file.
  </help>
</tool>';
 my $name = $self->dist_name_suffix . '.pl';
 my $vars = { name => $name };

my $output;
my $template = Template::Tiny->new;  
$template->process( \$input, $vars, \$output );  
  
return $output;
}

sub _build_template_bin {
    my $self = shift;
   
    my $input= '#!/usr/bin/perl -w

# usage : perl [% name %] <FASTA file> <output file>

open (IN, "<$ARGV[0]");
open (OUT, ">$ARGV[1]");
while (<IN>) {
    chop;
    if (m/^>/) {
        s/^>//;
        if ($. > 1) {
            print OUT sprintf("%.3f", $gc/$length) . "\n";
        }
        $gc = 0;
        $length = 0;
    } else {
        ++$gc while m/[gc]/ig;
        $length += length $_;
    }
}
print OUT sprintf("%.3f", $gc/$length) . "\n";
close( IN );
close( OUT );';

 my $name = $self->dist_name_suffix . '.pl';
 my $vars = { name => $name };

my $output;
my $template = Template::Tiny->new;  
$template->process( \$input, $vars, \$output );  
  
return $output;

}

sub _build_template_cmd_simple {
    my $self = shift;
    my $input =
    'use strict;
use warnings;
package [% toolpackage %]::Cmd;
use base qw(App::Cmd::Simple);
use IO::All;
use Data::Dumper;
use [% toolpackage %];

sub usage_desc { "[% toolname %].pl [OPTIONS] ARGS"; } 

sub opt_spec {
    return (
      [ "option1|f=s" , "Option 1" ]
    )
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    # if filename out is given, ensure its valid??    
    # validate there is sequence
    # $self->usage_error("No Options Defined") unless(  defined $opt->{option1}  );
  }
  
sub execute {
    my ($self, $opt, $args) = @_;

    my $[% toolname %] = [% toolpackage %]->new;
    my ($gc, $length);
    open (IN, "<", $args->[0]);
    open (OUT, ">", $args->[1]);
    while (<IN>) {
     chop;
     if (m/^>/) {
        s/^>//;
        if ($. > 1) {
            print OUT sprintf("%.3f", $gc/$length) . "\n";
        }
        $gc = 0;
        $length = 0;
     } else {
        ++$gc while m/[gc]/ig;
        $length += length $_;
     }
   }
   print OUT sprintf("%.3f", $gc/$length) . "\n";
   close( IN );
   close( OUT ); 
}
1;
';
my $toolpackage = $self->dist_name;
$toolpackage =~ s/-/::/g;
my $toolname = $self->dist_name_suffix;
my $vars = { toolpackage => $toolpackage, toolname => $toolname };

my $output;
my $template = Template::Tiny->new;  
$template->process( \$input, $vars, \$output );  
  
return $output;
 
}

sub _build_template_test_cmd_simple {
    my $self = shift;
    my $input = 'use Test::More tests => 1;
use App::Cmd::Tester;
use Data::Dumper;

use [% toolpackage %]::Cmd;

my $result = test_app([% toolpackage %]::Cmd => [ qw(td/[% toolname %]-test.fasta td/test_output_file.out) ]);
warn Dumper $result;
ok(1);
';

my $toolpackage = $self->dist_name;
$toolpackage =~ s/-/::/g;
my $toolname = $self->dist_name_suffix;
my $vars = { toolpackage => $toolpackage, toolname => $toolname };

my $output;
my $template = Template::Tiny->new;  
$template->process( \$input, $vars, \$output );  
  
return $output; 
}

sub _build_template_bin_cmd_simple {
    my $self = shift;
    my $input = '#!/usr/bin/env perl 
# usage : perl [% toolname %].pl <FASTA file> <output file>
use FindBin::libs;
use [% toolpackage %]::Cmd;
[% toolpackage %]::Cmd->run;
';

my $toolpackage = $self->dist_name;
$toolpackage =~ s/-/::/g;
my $toolname = $self->dist_name_suffix;
my $vars = { toolpackage => $toolpackage, toolname => $toolname };

my $output;
my $template = Template::Tiny->new;  
$template->process( \$input, $vars, \$output );  
  
return $output; 
}

sub _build_template_td_fasta_file {
    my $self = shift;
return '>test_input
ACGTTGGGTGTGTTAAAGGTG';
}


sub _build_template_bin_ui_cfg_tool {
    my $self = shift;
    my $input = '#!/usr/bin/env perl 
use strict;use warnings;
use Galaxy::Devel::UI::Builder;
use IO::All;

my $g = Galaxy::Devel::UI::Builder->new(id=>"fa_gc_content_1", name=>"Compute GC contents");
$g->desc("Compute GC content ");
$g->cmd( "perl", \'[% toolname %].pl $input $output\');
# ---- inputs
$g->in; 
$g->param( format=>"fasta", name=>"input", type=>"data", label=>"Source file");
# ---- outputs
$g->out; 
$g->data( format=>"tabular", name=>"output" );
# --- tests ---
$g->tests; 
$g->test;
$g->z->param(name=>"input", value=>"fa_gc_content_input.fa");
$g->output( name=>"out_file1", file=>"fa_gc_content_output.txt");
# --- help ---
$g->help("This tool computes GC content from a FASTA file.");
#print to file
print "printing..\n";
$g->xml->sprint > io("../cfg/[% toolname %].xml");
print "done\n";
';

my $toolpackage = $self->dist_name;
$toolpackage =~ s/-/::/g;
my $toolname = $self->dist_name_suffix;
my $vars = { toolpackage => $toolpackage, toolname => $toolname };

my $output;
my $template = Template::Tiny->new;  
$template->process( \$input, $vars, \$output );  
  
return $output; 
}

sub restore_remote_tool_conf {
    my $self = shift;
    my $type = shift; #either 'tool' or 'sec'
    my $custom_tool_dir = shift;
    $self->custom_tool_dir($custom_tool_dir) if defined( $custom_tool_dir); #otherwise defaults to myTools
    
    my $cmd = 
      "sudo -u galaxy cp " 
      . catdir( $self->gxy_central_dir, $self->tool_conf_name.'.bk.'.$type )   
      . " " 
      . catdir( $self->gxy_central_dir, $self->tool_conf_name );    
}

sub make_conf_backup {
    my $self = shift;
    my $suffix = shift;
    $suffix ||= '1'; #default is 1
    my $custom_tool_dir = shift;
    $self->custom_tool_dir($custom_tool_dir) if defined( $custom_tool_dir); #otherwise defaults to myTools
     my $cmd = 
      "sudo -u galaxy cp " 
      . catdir( $self->gxy_central_dir, $self->tool_conf_name )
      . " " 
      . catdir( $self->gxy_central_dir, $self->tool_conf_name.'.bk.'.$suffix );
}

sub restart_galaxy_cloud_service {
    my $self = shift;  
    my $domain = $self->host; 
    my $url = "http://$domain/cloud/root/restart_service?service_name=Galaxy";
    my $response = HTTP::Tiny->new->get($url);
}

sub dist_name_suffix_from_dist_name {
    my $self = shift;
    my $str  = shift;# || croak "No dist name\n";
    croak "No distribution prefix to determine distribution suffix " unless defined($self->dist_name_prefix);
    my $px = $self->dist_name_prefix;
    $str =~ /$px-(.+)$/;
    return $1;
}

sub read_remote_cpanm_log {
    my $self = shift;
    my $cmd = 'cat '.$self->remote_cpanm_log;
}

# To Do
sub remove_tmp_files {
    my $self = shift;  
}
sub remove_custom_dir {
    my $self = shift;    
}

no Any::Moose;
1;
__END__

=pod

=head1 NAME

App::Galaxy::Devel::Tool - A tool for Galaxy tool development and integration

=head1 VERSION

version 0.001

=head1 DESCRIPTION

App::Galaxy::Devel::Tool provides the galaxp command line utility to help development
of Perl based galaxy tools on galaxy cloud instances.

Running one of the following

    galaxp commands
    galaxp help

and then, for example, 

    galaxp help new 

to get more detailed information about the 'new' sub command. 

This class provides functionality used internally by the galaxp command line utility.

=head1 AUTHOR

NJWALKER <njwalker@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by NJWALKER.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

