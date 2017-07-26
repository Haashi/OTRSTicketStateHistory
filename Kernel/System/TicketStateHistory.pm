# Copyright (C) 2017 Haashii

package Kernel::System::TicketStateHistory;

use Kernel::Config;
use Kernel::System::Encode;
use Kernel::System::Log;
use Kernel::System::Main;
use Kernel::System::DB;
use Kernel::Language;

use strict;
use warnings;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    return $Self;
}

sub GetTicketStateHistoryText {

    my ( $Self, $Param ) = @_;

    my $ConfigObject = Kernel::Config->new();
    my $EncodeObject = Kernel::System::Encode->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $LanguageObject = Kernel::Language->new(
        MainObject   => $MainObject,
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
    );


    $DBObject->Connect();

    my $ticketid=$Param;

    #Credits to Crythias for the query
    my $requete="SELECT u.login                                                             owner,
           ts.name                                                             state,
           th.name                                                             fromto
           ,
           th.create_time
           createtime,
           th.ticket_id
           ticket_id,
           Coalesce((SELECT th2.create_time
                     FROM   ticket_history th2
                     WHERE  th2.history_type_id IN ( '1', '27' )
                            AND th2.ticket_id = th.ticket_id and ticket_id=".$ticketid."
                            AND th2.id > th.id
order by th2.id
                     LIMIT  1), Now())
           custom_date,
           Timestampdiff(second, th.create_time, Coalesce(
           (SELECT th2.create_time
            FROM   ticket_history th2
            WHERE  th2.history_type_id IN (
                   '1', '27' )
                   AND th2.ticket_id =
                       th.ticket_id
and ticket_id=".$ticketid."
                   AND th2.id > th.id
order by th2.id
            LIMIT  1), Now())) diff
    FROM   `ticket_history` th
           LEFT JOIN users u
                  ON u.id = th.owner_id
           LEFT JOIN ticket_state ts
                  ON ts.id = th.state_id
    WHERE  th.history_type_id IN ( '1', '27' ) and ticket_id=".$ticketid."
    ORDER  BY custom_date desc;";

    $DBObject->Prepare(SQL   => $requete,);

    #accounts the total time spent in each unique state
    my %Time=();
    my $day;
    my $minute;
    my $hour;
    my $second;
    while(my @row=$DBObject->FetchrowArray()){
      my ($agent,$state,$notused,$startdate,$id,$enddate,$diff)=@row;
      $state= $LanguageObject->Get($state);
      if(defined $Time{$state}){
        $Time{$state}+=$diff;
      }
      else{
        $Time{$state}=$diff;
      }
    }

    $DBObject->Disconnect();

    #Builds the text output
    my $Text="";
    foreach (keys %Time) {
      if( $Time{$_}<60){
        $Text="$_ : $Time{$_} sec.\n".$Text;
      }
      elsif( $Time{$_}<3600){
        $minute=int( $Time{$_}/60);
        $second= $Time{$_}%60;
        $Text="$_ : $minute min, $second sec \n".$Text;
      }
      elsif( $Time{$_}<3600*24){
        $hour=int( $Time{$_}/3600);
        $minute=int(( $Time{$_}-$hour*3600)/60);
        $second= $Time{$_}-3600*$hour-$minute*60;
        $Text= "$_ : $hour h, $minute min, $second sec \n".$Text;
      }
      else{
        $day=int( $Time{$_}/(3600*24));
        $hour=int(( $Time{$_}-$day*3600*24)/3600);
        $minute=int(( $Time{$_}-$day*3600*24-3600*$hour)/60);
        $second=( $Time{$_}-$day*3600*24-3600*$hour)-$minute*60;
        $Text= "$_ : $day d, $hour h, $minute min, $second sec \n".$Text;
      }
    }

    return $Text;
}

1;
