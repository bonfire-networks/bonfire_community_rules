defmodule Bonfire.CommunityRules.RuntimeConfig do
  use Bonfire.Common.Localise

  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  def config do
    import Config

    config :bonfire_community_rules, :qualifier_labels,
      yes: l("Allowed"),
      no: l("Not allowed"),
      with_label: l("Allowed with labeling / disclosure"),
      with_approval: l("Approval required")

    config :bonfire_community_rules, :template_rules,
      behavior: [
        name: l("Behavior"),
        sections: [
          behavior_custom: [
            rules: []
          ]
          # civility: [
          #   name: l("Civility & good-faith participation"),
          #   rules: [
          #     be_respectful: %{name: l("Be respectful to other members")},
          #     no_attacks: %{name: l("No personal attacks or insults")},
          #     no_trolling: %{
          #       name: l("No trolling, flamebait, or deliberately disruptive behavior")
          #     },
          #     respect_identity: %{name: l("Respect names, pronouns, and boundaries")},
          #     respect_moderators: %{
          #       name: l("Respect moderator instructions & Code of Conduct")
          #     }
          #   ]
          # ],
          # harassment: [
          #   name: l("Harassment and personal safety"),
          #   rules: [
          #     no_harassment: %{name: l("No harassment")},
          #     no_bullying: %{name: l("No bullying")},
          #     no_dogpiling: %{name: l("No dogpiling")},
          #     no_stalking: %{name: l("No stalking")},
          #     no_threats: %{name: l("No threats or intimidation")},
          #     no_doxxing: %{name: l("No doxxing")},
          #     no_block_evasion: %{name: l("No block evasion")},
          #     no_sexual_advances: %{name: l("No unwanted sexual advances")},
          #     no_misinfo: %{name: l("No misinformation / fake news")},
          #     no_repeated_contact: %{name: l("No repeated unwanted contact")},
          #     no_private_info: %{
          #       name: l("No posting private information without consent")
          #     }
          #   ]
          # ],
          # discrimination: [
          #   name: l("Discrimination and hateful conduct"),
          #   rules: [
          #     no_hate_speech: %{name: l("No hate speech")},
          #     no_racism: %{name: l("No racism")},
          #     no_sexism: %{name: l("No sexism or misogyny")},
          #     no_homophobia: %{name: l("No homophobia")},
          #     no_transphobia: %{name: l("No transphobia")},
          #     no_ableism: %{name: l("No ableism")},
          #     no_xenophobia: %{name: l("No xenophobia")},
          #     no_casteism: %{name: l("No casteism")},
          #     no_antisemitism: %{name: l("No antisemitism")},
          #     no_islamophobia: %{name: l("No Islamophobia")},
          #     no_misgendering: %{name: l("No targeted misgendering or deadnaming")},
          #     no_dehumanizing: %{
          #       name: l("No dehumanizing language toward protected groups")
          #     }
          #   ]
          # ],
          # authenticity: [
          #   name: l("Authenticity and account integrity"),
          #   rules: [
          #     no_impersonation: %{name: l("No impersonation"), has_qualifier: true},
          #     parody_accounts: %{name: l("Parody accounts"), has_qualifier: true},
          #     bot_accounts: %{name: l("Bot accounts"), has_qualifier: true}
          #   ]
          # ],
          # spam: [
          #   name: l("Spam, advertising, and platform misuse"),
          #   rules: [
          #     no_spam: %{name: l("No spam"), has_qualifier: true},
          #     no_mass_following: %{
          #       name: l("Mass-following or mass-replying"),
          #       has_qualifier: true
          #     },
          #     no_unsolicited_ads: %{
          #       name: l("Unsolicited advertising & unsolicited DMs for promotion"),
          #       has_qualifier: true
          #     },
          #     nonprofit_promotion: %{
          #       name: l("Personal project / non-commercial / non-profit promotion"),
          #       has_qualifier: true
          #     },
          #     commercial_ads: %{name: l("Commercial advertising"), has_qualifier: true},
          #     fundraising: %{
          #       name: l("Fundraising or donation requests"),
          #       has_qualifier: true
          #     },
          #     affiliate_links: %{name: l("Affiliate links"), has_qualifier: true},
          #     no_seo: %{name: l("SEO / link-farming accounts"), has_qualifier: true}
          #   ]
          # ],
          # onboarding: [
          #   name: l("Instance access & onboarding constraints"),
          #   rules: [
          #     must_be_adult: %{name: l("Users must be 18+")},
          #     must_provide_reason: %{
          #       name: l("Users must provide a reason for joining")
          #     },
          #     specific_community: %{
          #       name: l("This server is for a specific community or interest")
          #     },
          #     language_expectation: %{name: l("Primary language expectation")},
          #     manual_review: %{name: l("Registrations are manually reviewed")},
          #     must_complete_profile: %{
          #       name: l("Users must complete profile information")
          #     }
          #   ]
          # ]
        ]
      ],
      content: [
        name: l("Content"),
        sections: [
          content_custom: [
            rules: []
          ]
          # cw: [
          #   name: l("Content warnings & sensitive media labeling"),
          #   rules: [
          #     cw_sexual: %{name: l("Content warning for sexual content")},
          #     cw_violence: %{name: l("Content warning for graphic violence / gore")},
          #     cw_disturbing: %{
          #       name: l("Content warning for disturbing or traumatic topics")
          #     },
          #     cw_spoilers: %{name: l("Content warning for spoilers")},
          #     alt_text: %{name: l("Alt text for image posts")}
          #   ]
          # ],
          # ai: [
          #   name: l("AI-generated media, attribution, and copyright"),
          #   rules: [
          #     ai_media: %{name: l("AI-generated media"), has_qualifier: true},
          #     no_ai_impersonation: %{name: l("No AI impersonation of real people")},
          #     credit_creators: %{name: l("Credit original creators")},
          #     no_repost_without_permission: %{
          #       name: l("No reposting without permission")
          #     },
          #     no_copyright: %{name: l("No copyright infringement")},
          #     no_stolen_work: %{name: l("No scraped or stolen creative work")},
          #     credit_fanworks: %{
          #       name: l("Fanworks / derivatives must be credited where relevant")
          #     }
          #   ]
          # ],
          # nsfw: [
          #   name: l("Adult / explicit content rules"),
          #   rules: [
          #     explicit_sexual: %{name: l("Explicit sexual content"), has_qualifier: true},
          #     nudity: %{name: l("Nudity"), has_qualifier: true},
          #     adult_if_labeled: %{name: l("Adult content is allowed if labeled")},
          #     no_minor_sexualization: %{
          #       name: l("Sexualized depictions of minors"),
          #       has_qualifier: true
          #     },
          #     no_nonconsensual: %{
          #       name: l("Non-consensual sexual content"),
          #       has_qualifier: true
          #     },
          #     no_revenge_porn: %{
          #       name: l("Revenge porn / intimate media"),
          #       has_qualifier: true
          #     },
          #     nsfw_avatars: %{
          #       name: l("NSFW avatars / header images"),
          #       has_qualifier: true
          #     },
          #     real_person_explicit: %{
          #       name: l("Real-person explicit content"),
          #       has_qualifier: true
          #     }
          #   ]
          # ],
          # illegal: [
          #   name: l("Illegal / jurisdiction-specific prohibited content"),
          #   rules: [
          #     no_illegal: %{name: l("No illegal content under applicable local law")}
          #   ]
          # ],
          # violence: [
          #   name: l("Violence, threats, extremism, and self-harm"),
          #   rules: [
          #     violent_content: %{name: l("Violent content"), has_qualifier: true},
          #     extremist_propaganda: %{
          #       name: l("Extremist propaganda"),
          #       has_qualifier: true
          #     },
          #     terrorist_content: %{name: l("Terrorist content"), has_qualifier: true},
          #     self_harm: %{
          #       name: l("Self-harm / suicidal content"),
          #       has_qualifier: true
          #     }
          #   ]
          # ]
        ]
      ]
  end
end
