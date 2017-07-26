# Copyright (C) 2017 Haashii
# Using Kernel/Modules/AgentTicketHistory.pm as a template

package Kernel::Modules::AgentTicketStateHistory;

use strict;
use warnings;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::TicketStateHistory;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DBObject TicketObject LayoutObject LogObject UserObject ConfigObject)) {
        if ( !$Self->{$Needed} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Needed!" );
        }
    }
    $Self->{TicketStateHistoryObject} = Kernel::System::TicketStateHistory->new();

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Self->{TicketID} ) {

        # error page
        return $Self->{LayoutObject}->ErrorScreen(
            Message => 'Can\'t show history, no TicketID is given!',
            Comment => 'Please contact the admin.',
        );
    }

    # check permissions
    if (
        !$Self->{TicketObject}->TicketPermission(
            Type     => 'ro',
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID},
        )
        )
    {

        # error screen, don't show ticket
        return $Self->{LayoutObject}->NoPermission( WithHeader => 'yes' );
    }

    # get ACL restrictions
    $Self->{TicketObject}->TicketAcl(
        Data          => '-',
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = $Self->{TicketObject}->TicketAclActionData();

    # check if ACL resctictions if exist
    if ( IsHashRefWithData( \%AclAction ) ) {

        # show error screen if ACL prohibits this action
        if ( defined $AclAction{ $Self->{Action} } && $AclAction{ $Self->{Action} } eq '0' ) {
            return $Self->{LayoutObject}->NoPermission( WithHeader => 'yes' );
        }
    }

    my %Ticket = $Self->{TicketObject}->TicketGet( TicketID => $Self->{TicketID} );

    my @Lines = $Self->{TicketObject}->HistoryGet(
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
    );
    my $Tn = $Self->{TicketObject}->TicketNumberLookup( TicketID => $Self->{TicketID} );

    # get shown user info
    my @NewLines = ();
    if ( $Self->{ConfigObject}->Get('Ticket::Frontend::HistoryOrder') eq 'reverse' ) {
        @NewLines = reverse(@Lines);
    }
    else {
        @NewLines = @Lines;
    }
    @NewLines= grep{ $_->{HistoryType} eq 'StateUpdate' || $_->{HistoryType} eq 'NewTicket';} @NewLines;
    my $Table   = '';
    my $Counter = 1;
    for my $DataTmp (@NewLines) {
        $Counter++;
        my %Data = %{$DataTmp};

        # replace text
        if ( $Data{Name} && $Data{Name} =~ m/^%%/x ) {
            my %Info = ();
            $Data{Name} =~ s/^%%//xg;
            my @Values = split( /%%/x, $Data{Name} );
            $Data{Name} = '';
            for my $Value (@Values) {
                if ( $Data{Name} ) {
                    $Data{Name} .= "\", ";
                }
                $Data{Name} .= "\"$Value";
            }
            if ( !$Data{Name} ) {
                $Data{Name} = '" ';
            }
            $Data{Name} = $Self->{LayoutObject}->{LanguageObject}->Get(
                'History::' . $Data{HistoryType} . '", ' . $Data{Name}
            );

            # remove not needed place holder
            $Data{Name} =~ s/\%s//xg;
        }

        $Self->{LayoutObject}->Block(
            Name => 'Row',
            Data => {%Data},
        );

        if ( $Data{ArticleID} ne "0" ) {
            $Self->{LayoutObject}->Block(
                Name => 'ShowLinkZoom',
                Data => {%Data},
            );
        }
        else {
            $Self->{LayoutObject}->Block(
                Name => 'NoLinkZoom',
            );

        }
    }

    my %Data = ();

    $Data{TicketStateHistoryText} = $Self->{TicketStateHistoryObject}->GetTicketStateHistoryText($Self->{TicketID});

    my @states;
    my @times;
    my @all_nums;
    my $total;
    foreach (split(/\n/,$Data{TicketStateHistoryText})) {
      my ($state,$time)=split(/ : /,$_);
      @all_nums    = $time =~ /(\d+)/g;
      @all_nums = reverse @all_nums;
      @all_nums[3]=@all_nums[3]*3600*24;
      @all_nums[2]=@all_nums[2]*3600;
      @all_nums[1]=@all_nums[1]*60;
      @all_nums[0]=@all_nums[0];
      $total=$total+ eval join '+', @all_nums;
    }

    foreach (split(/\n/,$Data{TicketStateHistoryText})) {
      my ($state,$time)=split(/ : /,$_);
      push @states, $state;
      @all_nums    = $time =~ /(\d+)/g;
      @all_nums = reverse @all_nums;
      @all_nums[3]=@all_nums[3]*3600*24;
      @all_nums[2]=@all_nums[2]*3600;
      @all_nums[1]=@all_nums[1]*60;
      @all_nums[0]=@all_nums[0];
      my $sum = eval join '+', @all_nums;
      push @times, $sum;
      my %Data1= ("State"=>$state , "Time"=>$time, "Percent"=>sprintf("%.2f", $sum*100/$total)."%");
      $Self->{LayoutObject}->Block(
          Name => 'Row1',
          Data => {%Data1},
          );
    }

    # build page
    my $Output = $Self->{LayoutObject}->Header(
        Value => $Tn,
        Type  => 'Small',
    );

    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentTicketStateHistory1',
    );


    my $TimeData="[".join(",",@times)."]";
    my $StateData="[\"".join("\",\"",@states)."\"]";
    %Data=("Time"=>$TimeData,"State"=>$StateData);
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentTicketStateHistory2',
        Data=>\%Data,
    );

    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentTicketStateHistory',
        Data         => {
            TicketNumber => $Tn,
            TicketID     => $Self->{TicketID},
            Title        => $Ticket{Title},
        },
    );

    $Output .= $Self->{LayoutObject}->Footer(
    );

    return $Output;
}

1;
