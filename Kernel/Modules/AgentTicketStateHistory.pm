# Copyright (C) 2017 Haashii
# Using Kernel/Modules/AgentTicketHistory.pm as a template

package Kernel::Modules::AgentTicketStateHistory;
use strict; use warnings;
use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    # get needed object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    # check needed stuff
    if ( !$Self->{TicketID} ) {
        # error page
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Can\'t show history, no TicketID is given!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }
    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    # check permissions
    if (
        !$TicketObject->TicketPermission(
            Type => 'ro',
            TicketID => $Self->{TicketID},
            UserID => $Self->{UserID},
        )
        )
    {
        # error screen, don't show ticket
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }
    # get ACL restrictions
    my %PossibleActions = ( 1 => $Self->{Action} );
    my $ACL = $TicketObject->TicketAcl(
        Data => \%PossibleActions,
        Action => $Self->{Action},
        TicketID => $Self->{TicketID},
        ReturnType => 'Action',
        ReturnSubType => '-',
        UserID => $Self->{UserID},
    );
    my %AclAction = $TicketObject->TicketAclActionData();
    # check if ACL restrictions exist
    if ( $ACL || IsHashRefWithData( \%AclAction ) ) {
        my %AclActionLookup = reverse %AclAction;
        # show error screen if ACL prohibits this action
        if ( !$AclActionLookup{ $Self->{Action} } ) {
            return $LayoutObject->NoPermission( WithHeader => 'yes' );
        }
    }
    my %Ticket = $TicketObject->TicketGet( TicketID => $Self->{TicketID} );
    my @Lines = $TicketObject->HistoryGet(
        TicketID => $Self->{TicketID},
        UserID => $Self->{UserID},
    );
    my $Tn = $TicketObject->TicketNumberLookup( TicketID => $Self->{TicketID} );
    # get shown user info
    if ( $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::HistoryOrder') eq 'reverse' ) {
        @Lines = reverse(@Lines);
    }
    # Get mapping of history types to readable strings
    my %HistoryTypes;
    my %HistoryTypeConfig = %{ $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::HistoryTypes') // {} };
    for my $Entry ( sort keys %HistoryTypeConfig ) {
        %HistoryTypes = (
            %HistoryTypes,
            %{ $HistoryTypeConfig{$Entry} },
        );
    }

    @Lines= grep{ $_->{HistoryType} eq 'StateUpdate' || $_->{HistoryType} eq 'NewTicket';} @Lines;

    for my $Data (@Lines) {
	# replace text
        if ( $Data->{Name} && $Data->{Name} =~ m/^%%/x ) {
            $Data->{Name} =~ s/^%%//xg;
            my @Values = split( /%%/x, $Data->{Name} );
            $Data->{Name} = $LayoutObject->{LanguageObject}->Translate(
                $HistoryTypes{ $Data->{HistoryType} },
                @Values,
            );
            # remove not needed place holder
            $Data->{Name} =~ s/\%s//xg;
        }
        $LayoutObject->Block(
            Name => 'Row',
            Data => $Data,
        );
        if ( $Data->{ArticleID} ne "0" ) {
            $LayoutObject->Block(
                Name => 'ShowLinkZoom',
                Data => $Data,
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'NoLinkZoom',
            );
        }
    }
    #get TicketStateHistory object
    my $TicketStateHistoryObject = $Kernel::OM->Get('Kernel::System::TicketStateHistory');
    my %Data=();
    $Data{TicketStateHistoryText} = $TicketStateHistoryObject->GetTicketStateHistoryText($Self->{TicketID});

    # build page
    my $Output = $LayoutObject->Header(
        Value => $Tn,
        Type => 'Small',
    );
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentTicketStateHistory',
        Data => {
            TicketNumber => $Tn,
            TicketID => $Self->{TicketID},
            Title => $Ticket{Title},
        },
    );
    
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentTicketStateHistory1',
    );

    foreach (reverse split(/\n/,$Data{TicketStateHistoryText})) {
      $Data{TicketStateHistoryLine}=$_;
      $Output.= $LayoutObject->Output(
        Data=> \%Data,
        TemplateFile => 'AgentTicketStateHistory2',
      );
    }

    $Output .= $LayoutObject->Footer();
    return $Output;
}
1;
