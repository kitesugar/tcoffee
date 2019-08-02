#!/usr/bin/env perl
use Env;
use FileHandle;
use Cwd;
use File::Path;
use Sys::Hostname;
use Cwd;
use File::Copy;
use DirHandle;
use strict;
use DateTime;
use File::Basename;
use File::Find;


my $RETURN=" ####RETURN#### ";
my %cl;
my %dir;
my %lu;
#$GIT=0: no git interaction
#$GIT=1: Commit all new files, uncommit all deleted files
#$GIT=2: blank run

my $TIMEOUT=1500;#Default Timeout in seconds
my $TIMEOUT_ERROR=0;
my $KEEPREPLAYED=0;
my $GIT=0;
my %FILE2IGNORE;
my %FILES;
my @TMP_LIST;

my $PROCESSED=0;
my $FAILED=0;
my $WARNING=0;
my $PASSED=0;

my $max=0;
my $PATTERN='';
my $log ;
my $docslog;
my $regexp;
my $reset;
my $stop_on_failed;

my $play;
my $check;
my $clean;
my $UPDATE;
my $data="./";
my $outdir="./";
my $stream="input";
my $replay;
my $unplay;
my $STRICT=0;
my $VERY_STRICT=0;
my $failed;
my $rep;
my $cw=cwd();
my $mode="new";#will only run the new ones
my $pg="t_coffee";

$dir{examples}="$cw/examples/";
$dir{docs}    ="$cw/docs/";
$dir{tmp}     ="$cw/testsuite/validation/docs/tmp/";
$dir{ref}     ="$cw/testsuite/validation/docs/ref/";
$dir{latest}  ="$cw/testsuite/validation/docs/latest/";
$dir{log}     ="$cw/testsuite/validation/docs/log/";
$dir{failed}  ="$cw/testsuite/validation/docs/failed/";

$FILE2IGNORE{'stdout'}=1;
$FILE2IGNORE{'stderr'}=1;

if ($ARGV[0] eq "-help")
  {
    print "docs2test.pl\n";
    print "Automaticly checks t_coffee command lines\n";
    print "The github dir structure is expected by default\n";
    print "tcoffee/\n";
    print "       /docs     -> contains rst docs\n";
    print "       /examples -> contains the reference files\n";
    print "       /testsuite/validation/docs/\n"; 
    print "       /testsuite/validation/docs/tmp    -> computation\n";
    print "       /testsuite/validation/docs/ref    -> succesful dumps\n";
    print "       /testsuite/validation/docs/failed -> unsuccesful dumps\n";
    print "\n";
    print "Commands are extracted from the .rst files contained in <-docs>\n";
    print "Commands are recognised as any line starting with <-pattern>\n";
    print "Duplicated commands are checked only once\n";
    print "By default the program only checks the new commands (-mode=new) \n";
    print "To check All the commands against the references, use -mode validate\n";
    print "Dumps are containers containing the CL and the input files\n";
    print "flags:\n";
    print "     -pattern          pattern used to recognize the command lines [def=none]\n";
    print "                       pattern will be treated as a regexp if -regexp is set\n";
    print "     -regexp           flag that causes pattern to be treated as a perl regexp\n";
    print "     -pg               specify the path of the version of T-Coffee (optional)\n";
    print "     -log              default: validation.log\n";
    print "     -docslog          default: docs.log\n";
    print "     -mode=<action>    new|update|failed|check\n";
    print "                       new    : check ONLY CL w/o ref/dump and create ref/dump\n";
    print "                       update : check ALL  CL or create new ref/dum\n";
    print "                       failed : run   ONLY FAILURE as found /failed\n";
    print "                       check  : run   from dumps in ref";
    
    print "     -reset            delete all the dumps [CAUTION]\n";
    print "     -stop             stop at every FAILURE\n";
    print "     -clean            examples|dumps\n";
    print "                       examples: removes files in /examples/ not used by /docs [CAUTION]\n";
    print "                       dump:     removes files dumps not used by /docs [CAUTION]\n";
    
    print "     -rep              specifies a root repository\n";
    print "     -example          directory containing the sample files\n"; 
    print "     -docs             directory containing the .rst files\n";
    print "                       OR .rst file\n";
    print "                       OR file containing CLs (one per line)\n";
    print "     -ref              directory containing the reference dumps\n";
    print "                       OR dump file\n";
    print "     -failed           directory containing all the failed dumps\n";
    print "     -tmp              tmp directory\n";
    print "     -latest           latest directory\n";
    
    
    print "     -play   <file>    generates T-Coffee dumps using -dir data and putting all the dumps in -outdir. Existing dumps are updated if -update\n";
    print "     -check  <start>   prints the status of all the dumps. start: dump, list of dumps, recursive directory\n";
    print "     -clean  <string>  Removes while checking: ALL, FAILED, TIMEOUT, MISSING - FAILED removes FAILED+TIMEOUT+MISSING\n";
    print "     -replay <start>   replay and check existing dumps .   start: dump, list of dumps, recursive directory\n";
    
    print "     -unplay <file>    outputs all the input files from the dump files into -outdir, path are respected. Different files with identical names give an error\n";
    print "     -update           Recompute dumps already in -outdir\n";

    print "     -data   <dir>     directory containing all the data required by -play [def: current dir]\n";
    print "     -outdir <dir>     target_directory\n";
    print "     -stream string    stdin|stdout|all when -unplay [default=stdin]\n";

    
    print "     -keepreplayed     Keep the dump of the replayed dump. Will be named file.replayed and put in -outdir\n";
    print "     -strict           Will report failure if one or more replay output files are missing\n";
    print "     -very_strict      Will report failure if there is any difference between replay output\n";
    print "     -timeout          Will report failure is time is over this value [Def=$TIMEOUT sec.]\n";
    print "     -ignore           List of files to be ignoreed: File1 File2 Def: -ignore stdout stderr\n";
    
    
    print "     -max              max number of CL to check [DEBUG]\n";
    print "     -helppp             display this help message\n";
    
    
    
    print "\n";
    print "\n";
    die;
    }

@ARGV=clean_cl(@ARGV);

for (my $a=0; $a<=$#ARGV; $a++)
  {
    
    if ($ARGV[$a]=~/-pattern/)
      {
	$PATTERN=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-regexp/)
      {
	$regexp=1;
      }
    elsif ($ARGV[$a]=~/-reset/)
      {
	$reset=1;
      }
    elsif ($ARGV[$a]=~/-stop/)
      {
	$stop_on_failed=1;
      }
    elsif ($ARGV[$a]=~/-max/)
      {
	$max=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-pg/)
      {
	$pg=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-log/)
      {
	$log=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-docslog/)
      {
	$docslog=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-example/)
      {
	$dir{examples}=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-failed/)
      {
	$dir{failed}=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-docs/)
      {
	$dir{docs}=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-tmp/)
      {
	$dir{tmp}=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-ref/)
      {
	$dir{ref}=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-play/)
      {
	$play=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-check/)
      {
	$check=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-clean/)
      {
	$clean=$ARGV[++$a];
      } 
    elsif ($ARGV[$a]=~/-update/)
      {
	$UPDATE=1;
      }
    
    elsif ($ARGV[$a]=~/-data/)
      {
	$data=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-outdir/)
      {
	$outdir=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-replay/)
      {
	$replay=$ARGV[++$a];

      }
    elsif ($ARGV[$a]=~/-unplay/)
      {
	$unplay=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-stream/)
      {
	$stream=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-keepreplayed/)
      {
	$KEEPREPLAYED=1;
      }
    elsif ($ARGV[$a]=~/-rep/)
      {
	$rep=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-mode/)
      {
	$mode=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-timeout/)
      {
	$TIMEOUT=$ARGV[++$a];
      }
    elsif ($ARGV[$a]=~/-very_strict/)
      {
	$VERY_STRICT=1;
       
      }
    elsif ($ARGV[$a]=~/-strict/)
      {
	$STRICT=1;
      }
    elsif ($ARGV[$a]=~/-ignore/)
      {
	$FILE2IGNORE{$ARGV[++$a]}=1;
	while (!($ARGV[$a+1]=~/^-/))
	  {
	   $FILE2IGNORE{$ARGV[++$a]}=1;
	 }
      }
  }

# Replay Mode
my $exit_status;
my $infile;
if ($replay){$exit_status=replay_dump_list ($replay, $outdir);$infile=$replay;}
if ($play  ){$exit_status=play_dump_list ($play, $data, $outdir);$infile=$play}
if ($check ){$exit_status=check_dump_list ($check,$clean);$infile=$check}
if ($unplay){$exit_status=unplay_dump_list ($unplay, $stream,$outdir);$infile=$unplay}
if ($PROCESSED)
  {
    print "FULL SUMMARY:FILE: $infile TESTED $PROCESSED PASSED: $PASSED WARNING: $WARNING FAILED: $FAILED EXIT: $exit_status\n";
  }
exit ($exit_status);


sub unplay_dump_list
  {
    my ($unplay_list, $stream,$outdir)=@_;
    my $n=0;
    my $shell=0;
    
    if (!-d $outdir){system ("mkdir -p $outdir");}
    
    my @list=string2dump_list ($unplay_list);
    
    foreach my $d (@list)
      {
	unplay_dump($d,$stream,$outdir);
      }
  }
sub unplay_dump
    {
      my ($dump, $stream, $dir)=@_;
     
      
      print "---- unplay $dump\n";
     
      my %D=dump2report($dump);
      foreach my $f (keys (%{$D{file}}))
	{
	 
	  my $name=$f;
	  my $cstream=$D{file}{$f}{stream};
	  my $content=$D{file}{$f}{content};
	  my $fname="$dir/$name";
	  
	  
	  if ($lu{$stream}{$fname}{name})
	    {
	      if ($lu{$stream}{$fname}{content} eq $content){;}
	      else 
		{
		  my $pdump=$lu{$stream}{$fname}{dump};
		  printf "ERROR: uplay --- $name appears with different contents in $dump and $pdump [FATAL]\n";
		}
	    }
	  elsif (!$FILE2IGNORE{$f} && (($cstream eq $stream)|| ($stream eq "all")))
	    {
	      print "---- unplay $name\n";
	      $content=~s/$RETURN/\n/g;
	      my $f1 = new FileHandle;
	      open ($f1, ">$dir/$name");
	      print$f1 "$content";
	      close ($f1);
	      $lu{$stream}{$fname}{name}=$fname;
	      $lu{$stream}{$fname}{stream}=$stream;
	      $lu{$stream}{$fname}{content}=$content;
	      $lu{$stream}{$fname}{dump}=$dump;
	    }
	}
    return;
  }

	
sub play_dump_list
  {
    my ($file, $data,$outdir)=@_;
    my ($passed, $warning, $failed, $shell);
    my ($cdir, $wdir, $ldata,$n, $line, $cl, $rdata, $rfile, $routdir);
    my $f= new FileHandle;
   
        
    $file  =path2abs  ($file);
    $outdir=path2abs  ($outdir);
    $data  =path2abs  ($data);
    
    my $ffile = basename($file);
    my $path  = dirname ($file);

    $shell=$passed=$failed=$warning=0;
    
    if (!-d $data){printf ("Data directory must be provided  (try -data) [FATAL]\n");die;}
    if (!-e $file){printf ("List of command must be provided (try -play) [FATAL]\n");die;}

   
    
    

    $cdir=cwd;
    
    $wdir="./tmp/".random_string();
    system ("mkdir -p $wdir");
    
    $wdir=path2abs($wdir);
    $ldata="$wdir/data";


    if ($file =~/rst$/)
      {
	$rdata=$data;
	$data="$data/\./$ffile/";
	$rfile="$wdir/$ffile";
	$routdir="$outdir/$ffile/";
	system ("mkdir -p $routdir");
	
	$PATTERN='\$\$:';
	shortlines2longlines ($file, $rfile);
	
	
      }
    elsif ($file =~/tests$/)
      {
	$rdata=$data;
	$data="$data/\./$ffile/";
	$rfile=$file;
	$routdir="$outdir/$ffile/";
	system ("mkdir -p $routdir");
	print "$rfile\n";
		
      }
    else
      {
	$rfile=$file;
      }
    
    print "#PRODUCE DUMP FILES: $ffile\n";

    if (!$FILES{$rfile}){$FILES{$rfile}=1;}
    else
      {
	print "ERROR: Circular reference via $rfile [FATAL:doc2test.pl]\n";
	exit (1);
      }
      
    open ($f, "$rfile");
    chdir ($wdir);
    while (<$f>)
      {
	my $l=$_;
	chomp ($l);
	
	$line++;
	my $cl=line2cl ($l, $PATTERN);

	if ($l=~/rst$/ || $l=~/tests$/)
	  {

	    my $exit=play_dump_list ("$path/$l", $rdata, $outdir);
	    if ($exit){$shell=1;}
	  }
	elsif ($l=~/^#/ || !($l=~/\w/) || !$cl){;}#skip
	elsif  ($lu{$cl})#Do not recompute twice the same CL
	  {
	    my $dump=$lu{$cl}{dump};
	    print "File: $ffile Line:$line -- Command: $cl -- Dump: $dump -- SKIPPED\n";
	    $n++;
	    if ($lu{$cl}{exit} eq "FAILED"){$failed++;}
	    elsif ($lu{$cl}{exit} eq "WARNING"){$warning++;}
	    elsif ($lu{$cl}{exit} eq "PASSED") {$passed++;}
	  }
	elsif ( !$lu{$cl})
	  {
	    $n++;
	    my $dump="$ffile\.$n\.dump";
	    $dump=path2abs($dump);
	    my $ddump=basename($dump);
	    my %report;
	    my $target_dump="$routdir/$ddump";
	    my $cached;
	    if (-e "$target_dump" && !$UPDATE)
	      {
		%report=dump2report ($target_dump);
		$cached=1;
	      }
	    else
	      {
	
		
		if (-d $ldata){safe_rmrf($ldata);}#remove leftovers of previous run
		system ("cp -r $data $ldata");

		chdir ($ldata);
		system4tc ("export DUMP_4_TCOFFEE=$dump\;$cl;unset DUMP_4_TCOFFEE");
		%report=dump2report ($dump);
		
		$lu{$cl}{dump}=$dump;
		chdir ($wdir);
	      }
	    
	    my $status=$lu{$cl}{exit}=($TIMEOUT_ERROR)?"TIMEOUT":report2status (%report);
	    print "FILE: $ffile Line:$line -- Command: $cl -- Dump: $ddump -- $status ";
	    if ($cached){print "--- cached\n";}
	    else {print "\n";}
	    	    
	    if    ($status eq "TIMEOUT"){create_error_dump ("$routdir/$ddump", $cl, "ERROR FATAL TIMEOUT");}
	    elsif ($status eq "MISSING"){create_error_dump ("$routdir/$ddump", $cl, "ERROR FATAL MISSING");}
	    elsif ($cached){;}
	    else 
	      {system ("mv $dump $routdir/$ddump");}
	    
	    if ($status eq "FAILED" || $status eq "TIMEOUT" || $status eq "MISSING")
	      {
		$shell=1;
		$failed++;
	      }
	    elsif ($status eq "WARNING")
	      {
		$warning++;
		if ( $VERY_STRICT){$shell=1;}
	      }
	    else{$passed++;}
	    
	    if ($STRICT && $shell){exit ($shell);}
	    if ($VERY_STRICT && $shell){exit ($shell);}
	    
	  }
      }
    close ($f);
    
    chdir ($cdir);
    safe_rmrf ($wdir);
    
    print "SUMMARY:FILE $ffile TESTED $n PASSED: $passed WARNING: $warning FAILED: $failed\n";
    return $shell;
  }

sub check_dump_list
    {
      my ($start,$clean)=@_;
      my @list=string2dump_list ($start);
      
      foreach my $d (@list)
	{
	  my %report=dump2report ($d);
	  my $status=report2status (%report);
	  my $cl=dump2cl ($d);
	  print "$d -- $cl -- $status";
	  if ($clean)
	    {
	      my $ul=0;
	      if ($clean eq "ALL"){$ul=1;}
	      elsif ($clean eq "FAILED" && $status ne "PASSED"){$ul=1;}
	      elsif ($clean eq $status){$ul=1;}
	  
	      if ( $ul)
		{
		  print " *** Removed";
		  unlink ($d);
		}
	      
	    }
	  print "\n";
	}
      exit (0);
    }

sub safe_rmrf
  {
    my ($dir)=@_;
    if ( -d $dir && $dir=~/RANDOMSTRING/){system ("rm -rf $dir"); }
    else 
      {
	print STDERR "COWARDINGLY Refused to rm -rf $dir that does not contain the RANDOMSTRING tag\n";
      }
  }

sub replay_dump_list
  {
    my ($replay_list, $outdir)=@_;
    my $n=0;
    my $shell=0;
    

    my @list=string2dump_list ($replay_list);
    print "* Replay $#list datasets. Start: $replay_list\n";
    foreach my $d (@list)
      {
	if (replay_dump_file ($d)){$shell=1;}
      }
    return $shell;
  }

      
sub replay_dump_file
  {
    my ($replay, $outdir, $name)=@_;
    my $replayed=$replay.".replay";
    my ($shell,$etime)=dump2run ($replay, $replayed, "quiet");
    my $com=dump2cl ($replay);
    my ($missing, $different, $error, $warning);
    
    if (!$name){$name=basename ($replay);}
    
    
    $replayed=path2abs($replayed);
    
    $missing=$warning=$error=$different=0;
    print "~ ($name) $com $etime ms ";
    my %in =dump2report($replay);
    my %out=dump2report($replayed);
    
    compare_reports (\%in, \%out, "quiet");
    $missing=$out{MissingOutput};
    $different=$out{N_DifferentOutput};
    $error=$out{error};
    
    if (!$error){$error=0;}
    if (!$warning){$warning=0;}
    if (!$different){$different=0;}
    if (!$missing){$missing=0;}
    
    
    print "MISSING_IO $missing ";
    print "DIFFERENT_IO $different ";
    print "WARNINGS $warning ";
    print "ERRORS $error ";
    
    if    ($STRICT && ($error || $missing)){$shell=1;}
    elsif ($VERY_STRICT && ($error || $missing || $warning || $different)){$shell=1;}
    
    if (!$shell)
      {
	print "PASSED\n";
      }
    else
      {
	print "FAILED\n";
      }
    if ($KEEPREPLAYED)
      {
	print "Replay File: $replayed\n";
	system ("mv $replayed $outdir");
      }
    else
      {
	unlink ($replayed);
      }
    return ($SHELL);
  }
  
#End of single replay      


sub dir2dump
  {
    my ($cl, $dir, $mode, $num)=@_;
    my ($d,@list);
    
    $d=$dir->{$mode};
    my @list=dir2file_list ($d);
        
    foreach my $dump (@list)
      {
	$dump="$d/$dump";
	if ($dump=~/t_coffee\.(\d+).dump/ && !($dump=~/.*dump.new.*/))
	  {	
	    my $cn=$1;
	    $num=($cn>$num)?$cn:$num;
	    my $com=dump2cl($dump);
	    $cl->{$com}{0}{$mode}=$dump;
	  }
      }
    return $num;
  }
sub compare_reports
  {
    my ($ref, $doc, $quiet)=@_;

    
    if (!$ref || !$doc){return;}
    
    foreach my $f (keys (%{$ref->{file}}))
      {
	if ($quiet ne "quiet")
	  {print "FILE: $f";
	   print "********\n\n";
	   print "($doc->{file}{$f}{content}\n\n\n\n($ref->{file}{$f}{content}\n\n\n";
	   print "********\n\n";
	 }


	if (!$FILE2IGNORE{$f})
	  {
	    #Get rid of the Version and CPU effects
	    my $content1=$doc->{file}{$f}{content};
	    my $content2=$doc->{file}{$f}{content};
	    
	    $content1=~s/Version_\S+ /Version_XXXX /g;
	    $content2=~s/Version_\S+ /Version_XXXX /g;
	    
	    $content1=~s/CPU\S+ /CPU=XXXX /g;
	    $content2=~s/CPU\S+ /CPU=XXXX /g;
	    
	    if (!$doc->{file}{$f})
	      {
		$doc->{MissingOutputF}{$f}=1;$doc->{MissingOutput}++;
	      }
	    elsif ($content1 ne $content2)
	      {
		$doc->{DifferentOutput}{$f}=1;$doc->{N_DifferentOutput}++;
	      }
	    if ($doc->{warning} && !$ref->{warning})
	      {
		$doc->{new_warning}=1;
	      }
	  }
      }
    return;
  }
sub system4tc
    {
      my $com=shift;
      system ("t_coffee -clean >/dev/null 2>/dev/null");
      return timeout_system ($com);
    }

sub dump2run
  {
    my ($idump, $odump, $com)=@_;
    my $cdir=cwd;
    my $use_stdout;
    my $shell;
    
    $idump=path2abs($idump);
    $odump=path2abs($odump);
    
    
    my $dir="tmp/".random_string();

    system ("mkdir -p $dir");
    chdir  ($dir);
    
    if (!$com){$com=dump2cl($idump);}
    $com=dump2cl($idump);
    
    if ($com =~/.*\|(.*)/)
      {
	$com=$1;
      }
    my %ref=xml2tag_list ($idump, "file");
    

    for (my $i=0; $i<$ref{n};$i++)
	{
	  
	  my $stream=xmltag2value($ref{$i}{body},"stream");
	  my $name=xmltag2value($ref{$i}{body},"name");
	  my $content=xmltag2value($ref{$i}{body},"content");
	  $content=~s/$RETURN/\n/g;
	  
	  
	  if ($stream eq "input")
	    {
	      my $dir=dirname ($name);
	      $dir="./$dir";
	      system ("mkdir -p $dir");
	      
	      open (F, ">$name");
	      print F "$content";
	      close (F);
	      
	      if ($name eq "stdin"){$com="cat stdin | $com";}
	    }
	  if ($stream eq "output" && $name eq "stdout"){$use_stdout=1;}
	}
    
   
    my $before=time;
    unlink ($odump);
    if (!$use_stdout)
      {
	$shell=system4tc ("export DUMP_4_TCOFFEE=$odump;$com >/dev/null 2>/dev/null");
      }
    else
      {
	$shell=system4tc ("export DUMP_4_TCOFFEE=$odump;$com >stdout 2>/dev/null");
      }
    my $etime=time - $before;
    $etime*=1000;
        
    chdir($cdir);
    safe_rmrf($dir);
    
    return ($shell, $etime);
  }
  
sub dump2report
  {
      my ($dump)=shift;
      my $cdir=cwd;
      my %ref;
      if (!$dump || !-e $dump){return %ref;}
     
      %ref=xml2tag_list ($dump, "file");
      
      for (my $i=0; $i<$ref{n};$i++)
	{
	  my $stream=xmltag2value($ref{$i}{body},"stream");
	  my $name=xmltag2value($ref{$i}{body},"name");
	  my $content=xmltag2value($ref{$i}{body},"content");
	
	if ($name  eq "stdout" || $name  eq "stderr")
	  {
	    $ref{$name}=$content;
	  }
	else
	  { 
	   $ref{file}{$name}{stream}=$stream;
	   $ref{file}{$name}{content}=$content;
	   $ref{nfiles}++;
	 }
	}
      $ref{stack}=dump2stack ($dump);
      my $stderr=$ref{stderr};
      my $stdout=$ref{stdout};
    
      if ($stderr=~/ERROR/ || $stderr =~/FATAL/)
	{
	  $ref{error}=1;
	}
      $ref{warning}=($stderr=~/WARNING/g);
    
      return %ref
  }
  
sub dump2stack
    {
      my ($file)=@_;
      
      my %cl=xml2tag_list ($file, "stack");
     
      my $stack= $cl{0}{body};

      if (!$stack){return "";}
      return $stack;
      
    }

sub dump2cl
   {
     my ($file)=@_;
     my %cl=xml2tag_list ($file, "cl");
     return clean_command ($cl{0}{body});
   }

sub clean_command
      {
	my $c=shift;
	$c=~s/\s+/ /g;
	$c=~s/^\s+//g;
	$c=~s/\s+$//g;
	return $c;
      }

#xml parsing

sub xmltag2value
  {
    my ($string_in, $tag)=@_;
    my %TAG;
    %TAG=xml2tag_list ($string_in, $tag);
    return $TAG{0}{body};
  }

sub xml2tag_list
  {
    my ($string_in,$tag)=@_;
    my ($tag_in, $tag_out, $string, $tag_in1, $tag_in2);
    my (@l, $in, $n, $t);
    my %tag;
    
    if (-e $string_in)
      {
	$string=&file2string ($string_in);
      }
    else
      {
	$string=$string_in;
      }
    
    my $cwd=$cw;
    
    $tag_in1="<$tag ";
    $tag_in2="<$tag>";
    $tag_out="/$tag>";
    $string=~s/>/>##1/g;
    $string=~s/</##2</g;
    $string=~s/##1/<#/g;
    $string=~s/##2/#>/g;
    @l=($string=~/(\<[^>]+\>)/g);
    $tag{n}=0;
    $in=0;$n=-1;
    
    foreach $t (@l)
      {
	
	$t=~s/<#//;
	$t=~s/#>//;
	
	if ( $t=~/$tag_in1/ || $t=~/$tag_in2/)
	  {
	    $in=1;
	    $tag{$tag{n}}{open}=$t;
	    $n++;

	  }
	elsif ($t=~/$tag_out/)
	  {


	    $tag{$tag{n}}{close}=$t;
	    $tag{n}++;
		
	    $in=0;
	    
	  }
	elsif ($in)
	  {
	    $tag{$tag{n}}{body}.=$t;
	  }
      }
    
    return %tag;
  }

sub file_isdump
    {
      my $f=shift;
      if (!-e $f) {return 0;}
      open (F, "$f");
      while (<F>)
	{
	  my $l=$_;
	  close (F);
	  return $l=~/DumpIO/;
	}
    }


    
sub file2string
  {
    my $f=@_[0];
    my ($string, $l);
    open (F,"$f");
    while (<F>)
      {

	$l=$_;
	#chomp ($l);
	$string.=$l;
      }
    close (F);
    $string=~s/\r\n//g;
    $string=~s/\n/$RETURN/g;
    return $string;
  }


sub tag2value
  {

    my $tag=(@_[0]);
    my $word=(@_[1]);
    my $return;

    $tag=~/$word="([^"]+)"/;
    $return=$1;
    return $return;
  }
sub clean_cl
    {
      my @argl=@_;
      my $argv;
      foreach my $a (@argl)
	{
	  $a=~s/ /###SPACE###/g;
	  $argv.="$a ";
	}
      
      $argv=~s/[=,;]/ /g;
      @argl=split (/\s+/, $argv);
      for (my $a=0; $a<=$#argl; $a++){$argl[$a]=~s/###SPACE###/ /g;}
      
      return @argl;
    }

# Git functions



sub dir2file_list
     {
       my ($cd, $pattern)=@_;
       my (@l, @nl);

       if (!-d $cd){return;}
       opendir (DIR, $cd);
       @l=readdir (DIR);
       closedir (DIR);
       
       foreach my $f (@l)
	 {
	   if ($f ne "." && $f ne "..")
	     {
	       if ($pattern)
		 {
		   if ($f=~/$pattern/){push (@nl,$f);}
		 }
	       else {{push (@nl,$f);}}
	     }
	 }
       return @nl;
     }
     
sub random_string
       {
	 my $l=shift;

	 if (!$l){$l=20;}
	 my $ret;
	 my $s="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
	 my @l=split (//,$s);
	 for (my $a=0; $a<$l; $a++)
	   {
	     my $c=int(rand($#l+1));
	     $ret.=$l[$c];
	   }
	 return "RANDOMSTRING$ret";
       }

sub path2abs
	{
	  my ($file)=@_;
	  if ($file=~/^^\//){return $file;}
	  my $dir=cwd;
	  $file=$dir."/".$file;
	  $file =~s/\/\//\//g;
	  
	  return $file;
	}
sub timeout_system
   {
     my ($command, $timeout)=(@_);
     my $shell;
     $TIMEOUT_ERROR=0;
     if (!$timeout)
       {
	 $timeout=$TIMEOUT;
       }

     eval 
       {
	 local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
	 
	 alarm($timeout);
	 $shell=system ($command);
	 alarm(0);
       };
     
     if ($@ eq "alarm\n")
       {
	 $TIMEOUT_ERROR=1;
	 return "-1";
       }
     else {return $shell}
   }

sub string2dump_list
     {
       my ($string)=@_;
       my @dump_list;
       

       @TMP_LIST=();
       if (file_isdump($string)){return $string; }
       elsif (-d $string)
	 {
	   dir2dump_list ($string);}
       elsif (-f $string){file2dump_list($string);}
       
       @dump_list=@TMP_LIST;
       @TMP_LIST=();
       return @dump_list;
     }
sub file2dump_list
     {
       my ($file)=@_;
       my $f= new FileHandle;
       #Note: no return is needed because the global TMP_LIST is incremented
       #Use of a global variable is imposed by find
       open ($f, "$file");
       while (<$f>)
	 {
	   my $l=$_;
	   chomp ($l);
	   if (file_isdump($l))
	     {
	       $l=path2abs($l);
	       push (@TMP_LIST, $l);
	     }
	   elsif (-f $l)
	     {
	       file2dump_list ($l);
	     }
	   elsif (-d $l)
	     {
	       dir2dump_list ($l);
	     }
	 }
       
       close ($f);
       return @TMP_LIST;
     }
     
sub dir2dump_list
  {
    my ($dir)=@_;

    find (\&eachDumpFile, $dir);
    return @TMP_LIST;
  }
  
sub eachDumpFile 
    {
      my $filename =$_;
      my $fullpath = $File::Find::name;
      
      #remember that File::Find changes your CWD, 
      #so you can call open with just $_
      my $abs=path2abs($filename);
       
      if (file_isdump($filename))	
	{ 
	  push (@TMP_LIST, "$abs");
	}
    }
sub line2cl
      {
	my ($cl, $pattern)=@_;
	if ( !$pattern){return $cl;}
	elsif ($pattern && !($cl=~/^\s*$pattern/)){return 0;}
	else
	  {
	    $cl=~s/$pattern//;
	    return $cl;
	  }
	}
	
sub shortlines2longlines
	{
	  my ($inF, $outF)=@_;
	  my $in=new FileHandle;
	  my $out=new FileHandle;

	  open ($in, "$inF");
	  open ($out, ">$outF");
	  

	  while (<$in>)
	    {
	      my $l=$_;
	      if ( ($l=~/\\/))
		{
		  $l=~s/\\/ /g;
		  chomp ($l);
		}
	      print $out "$l";
	    }
	  close ($in);
	  close ($out);

	}

sub create_error_dump
	  {
	    my ($file, $cl, $msg)=@_;
	    my $f = new FileHandle;
	    
	    open ($f, ">$file");
	    print $f "<DumpIO>\n";
	    print $f "<nature>standard dump</nature>\n";
            print $f "<program>T-COFFEE</program>\n";
	    print $f "<cl>$cl</cl>\n";
	    print $f "<file>\n";
	    print $f "<stream>output</stream>\n";
	    print $f "<name>stderr</name>\n";
	    print $f "<content>$msg</content>\n";
	    print $f "</file>\n";
	    print $f "<error>TIMEOUT</error>\n";
	    print $f "<DumpStatus>OK</DumpStatus>\n";
	    print $f "</DumpIO>\n";
	    close ($f);
	  }
sub report2status
	  {
	    my (%report)=@_;
	    $PROCESSED+=1;
	    
	    if    (!%report) 
	      {
		$FAILED+=1;
		return "MISSING";
	      }
	    elsif ($report{error})
	      {
		if ($report{stderr}=~/TIMEOUT/)
		  {
		    $FAILED+=1;
		    return "TIMEOUT";
		  }
		else
		  {
		    $FAILED+=1;
		    return "FAILED";
		  }
	      }
	    elsif ($report{warning})
	      {
		$WARNING+=1;
		return "WARNING";
	      }
	    elsif ($report{newwarning})
	      {
		
		return "NEW_WARNING";
	      }
	    else
	      {
		$PASSED+=1;
		return "PASSED";
	      }
	  }
	  
