CREATE TABLE public.applied_themes (
                                       user_id uuid NOT NULL DEFAULT auth.uid(),
                                       theme_id uuid NOT NULL DEFAULT gen_random_uuid(),
                                       CONSTRAINT applied_themes_pkey PRIMARY KEY (user_id),
                                       CONSTRAINT apllied_themes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                       CONSTRAINT apllied_themes_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(id)
);
CREATE TABLE public.ban_appeals (
                                    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                    created_at timestamp with time zone NOT NULL DEFAULT now(),
                                    user_id uuid NOT NULL,
                                    appeal_message text NOT NULL,
                                    approved boolean,
                                    answer text,
                                    reviewer_id uuid,
                                    CONSTRAINT ban_appeals_pkey PRIMARY KEY (id),
                                    CONSTRAINT ban_appeals_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                    CONSTRAINT ban_appeals_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.categories (
                                   id text NOT NULL,
                                   name text NOT NULL,
                                   description text,
                                   CONSTRAINT categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.comment_likes (
                                      user_id uuid NOT NULL,
                                      comment_id bigint NOT NULL,
                                      created_at timestamp with time zone DEFAULT now(),
                                      CONSTRAINT comment_likes_pkey PRIMARY KEY (user_id, comment_id),
                                      CONSTRAINT comment_likes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id),
                                      CONSTRAINT comment_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.comments (
                                 id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                 author_id uuid NOT NULL,
                                 video_id bigint NOT NULL,
                                 content character varying NOT NULL,
                                 created_at timestamp with time zone DEFAULT now(),
                                 parent_id bigint,
                                 reply_count integer NOT NULL DEFAULT 0,
                                 like_count integer NOT NULL DEFAULT 0,
                                 CONSTRAINT comments_pkey PRIMARY KEY (id),
                                 CONSTRAINT comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id),
                                 CONSTRAINT comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.comments(id),
                                 CONSTRAINT comments_video_id_fkey FOREIGN KEY (video_id) REFERENCES public.videos(id)
);
CREATE TABLE public.conversation_members (
                                             conversation_id bigint NOT NULL,
                                             profile_id uuid NOT NULL,
                                             role text NOT NULL DEFAULT 'member'::text,
                                             joined_at timestamp with time zone NOT NULL DEFAULT now(),
                                             last_read_message_id bigint,
                                             CONSTRAINT conversation_members_pkey PRIMARY KEY (conversation_id, profile_id),
                                             CONSTRAINT conversation_members_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
                                             CONSTRAINT conversation_members_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.conversations (
                                      id bigint NOT NULL DEFAULT nextval('conversations_id_seq'::regclass),
                                      type text NOT NULL CHECK (type = ANY (ARRAY['direct'::text, 'group'::text])),
                                      created_by uuid NOT NULL,
                                      title text,
                                      created_at timestamp with time zone NOT NULL DEFAULT now(),
                                      updated_at timestamp with time zone NOT NULL DEFAULT now(),
                                      last_message text NOT NULL DEFAULT ''::text,
                                      CONSTRAINT conversations_pkey PRIMARY KEY (id),
                                      CONSTRAINT conversations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.dislikes (
                                 user_id uuid NOT NULL,
                                 video_id bigint NOT NULL,
                                 created_at timestamp with time zone DEFAULT now(),
                                 CONSTRAINT dislikes_pkey PRIMARY KEY (user_id, video_id),
                                 CONSTRAINT dislikes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                 CONSTRAINT dislikes_video_id_fkey FOREIGN KEY (video_id) REFERENCES public.videos(id)
);
CREATE TABLE public.follows (
                                follower_id uuid NOT NULL,
                                following_id uuid NOT NULL,
                                created_at timestamp with time zone DEFAULT now(),
                                CONSTRAINT follows_pkey PRIMARY KEY (follower_id, following_id),
                                CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.profiles(id),
                                CONSTRAINT follows_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.interactions (
                                     id bigint NOT NULL DEFAULT nextval('interactions_id_seq'::regclass),
                                     user_id uuid NOT NULL,
                                     created_at timestamp with time zone NOT NULL DEFAULT now(),
                                     video_id bigint NOT NULL,
                                     interaction_type text NOT NULL CHECK (interaction_type = ANY (ARRAY['view'::text, 'like'::text, 'share'::text, 'comment'::text])),
                                     CONSTRAINT interactions_pkey PRIMARY KEY (id),
                                     CONSTRAINT interactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                     CONSTRAINT interactions_video_id_fkey FOREIGN KEY (video_id) REFERENCES public.videos(id)
);
CREATE TABLE public.likes (
                              user_id uuid NOT NULL,
                              video_id bigint NOT NULL,
                              created_at timestamp with time zone DEFAULT now(),
                              CONSTRAINT likes_pkey PRIMARY KEY (user_id, video_id),
                              CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                              CONSTRAINT likes_video_id_fkey FOREIGN KEY (video_id) REFERENCES public.videos(id)
);
CREATE TABLE public.messages (
                                 id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                 conversation_id bigint NOT NULL,
                                 sender_id uuid,
                                 content text,
                                 type text NOT NULL DEFAULT 'text'::text,
                                 reply_to_message_id bigint,
                                 created_at timestamp with time zone NOT NULL DEFAULT now(),
                                 deleted_at timestamp with time zone,
                                 CONSTRAINT messages_pkey PRIMARY KEY (id),
                                 CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
                                 CONSTRAINT messages_reply_to_message_id_fkey FOREIGN KEY (reply_to_message_id) REFERENCES public.messages(id),
                                 CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profile_levels (
                                       user_id uuid NOT NULL DEFAULT auth.uid(),
                                       category text NOT NULL DEFAULT ''::text,
                                       level real NOT NULL DEFAULT '0'::real,
                                       CONSTRAINT profile_levels_pkey PRIMARY KEY (user_id, category),
                                       CONSTRAINT profile_levels_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                       CONSTRAINT profile_levels_category_fkey FOREIGN KEY (category) REFERENCES public.categories(id)
);
CREATE TABLE public.profile_quest_progress (
                                               user_id uuid NOT NULL DEFAULT gen_random_uuid(),
                                               quest_id bigint NOT NULL,
                                               progress real NOT NULL DEFAULT '0'::real,
                                               CONSTRAINT profile_quest_progress_pkey PRIMARY KEY (user_id, quest_id),
                                               CONSTRAINT profile_quest_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                               CONSTRAINT profile_quest_progress_quest_id_fkey FOREIGN KEY (quest_id) REFERENCES public.quests(id)
);
CREATE TABLE public.profiles (
                                 id uuid NOT NULL,
                                 username character varying NOT NULL UNIQUE,
                                 display_name character varying,
                                 avatar_url text,
                                 bio character varying,
                                 created_at timestamp with time zone DEFAULT now(),
                                 followers_count integer NOT NULL DEFAULT 0 CHECK (followers_count >= 0),
                                 following_count integer NOT NULL DEFAULT 0 CHECK (following_count >= 0),
                                 total_likes_count integer NOT NULL DEFAULT 0,
                                 total_videos_count integer NOT NULL DEFAULT 0,
                                 is_banned boolean NOT NULL DEFAULT false,
                                 accepted_eula boolean NOT NULL DEFAULT false,
                                 accepted_data_processing boolean NOT NULL DEFAULT false,
                                 onboarding_completed boolean NOT NULL DEFAULT false,
                                 CONSTRAINT profiles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.quest_connection_versions (
                                                  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                                  connection_id bigint NOT NULL,
                                                  type text DEFAULT 'prerequisite'::text,
                                                  is_deleted boolean NOT NULL DEFAULT false,
                                                  update_message text NOT NULL DEFAULT ''::text,
                                                  created_at timestamp with time zone NOT NULL DEFAULT now(),
                                                  created_by uuid NOT NULL,
                                                  xp_requirement real,
                                                  CONSTRAINT quest_connection_versions_pkey PRIMARY KEY (id),
                                                  CONSTRAINT quest_connection_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
                                                  CONSTRAINT quest_connection_versions_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.quest_connections(connection_id),
                                                  CONSTRAINT quest_connection_versions_created_by_fkey1 FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.quest_connections (
                                          from_id bigint NOT NULL,
                                          to_id bigint NOT NULL,
                                          created_at timestamp with time zone NOT NULL DEFAULT now(),
                                          created_by uuid NOT NULL,
                                          connection_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                          CONSTRAINT quest_connections_pkey PRIMARY KEY (connection_id),
                                          CONSTRAINT quest_connections_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
                                          CONSTRAINT quest_connections_from_id_fkey FOREIGN KEY (from_id) REFERENCES public.quests(id),
                                          CONSTRAINT quest_connections_to_id_fkey FOREIGN KEY (to_id) REFERENCES public.quests(id)
);
CREATE TABLE public.quest_connections_latest (
                                                 last_updated_at timestamp with time zone NOT NULL DEFAULT now(),
                                                 last_updated_by uuid NOT NULL,
                                                 connection_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                                 is_deleted boolean NOT NULL DEFAULT false,
                                                 type text NOT NULL DEFAULT ''::text,
                                                 xp_requirement real NOT NULL DEFAULT '0'::real,
                                                 CONSTRAINT quest_connections_latest_pkey PRIMARY KEY (connection_id),
                                                 CONSTRAINT quest_connections_latest_last_updated_by_fkey FOREIGN KEY (last_updated_by) REFERENCES public.profiles(id),
                                                 CONSTRAINT quest_connections_latest_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.quest_connections(connection_id)
);
CREATE TABLE public.quest_versions (
                                       id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                       created_at timestamp with time zone NOT NULL DEFAULT now(),
                                       created_by uuid,
                                       quest_id bigint NOT NULL,
                                       update_message text NOT NULL DEFAULT ''::text,
                                       title text,
                                       description text,
                                       difficulty real,
                                       pos_x bigint,
                                       pos_y bigint,
                                       size_x smallint,
                                       size_y smallint,
                                       is_deleted boolean,
                                       subject text,
                                       color bigint,
                                       CONSTRAINT quest_versions_pkey PRIMARY KEY (id),
                                       CONSTRAINT quest_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
                                       CONSTRAINT quest_versions_quest_id_fkey FOREIGN KEY (quest_id) REFERENCES public.quests(id)
);
CREATE TABLE public.quests (
                               id bigint NOT NULL UNIQUE,
                               created_at timestamp with time zone NOT NULL DEFAULT now(),
                               created_by uuid NOT NULL,
                               CONSTRAINT quests_pkey PRIMARY KEY (id),
                               CONSTRAINT quests_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.quests_latest (
                                      quest_id bigint NOT NULL,
                                      title text NOT NULL DEFAULT ''::text,
                                      description text NOT NULL DEFAULT ''::text,
                                      difficulty real NOT NULL DEFAULT 0.2,
                                      pos_x bigint NOT NULL DEFAULT 0,
                                      pos_y bigint NOT NULL DEFAULT 0,
                                      size_x smallint NOT NULL DEFAULT 200,
                                      size_y smallint NOT NULL DEFAULT 100,
                                      is_deleted boolean NOT NULL DEFAULT false,
                                      subject text NOT NULL DEFAULT ''::text,
                                      updated_at timestamp with time zone NOT NULL DEFAULT now(),
                                      version_id bigint,
                                      color bigint NOT NULL DEFAULT '4294967295'::bigint,
                                      CONSTRAINT quests_latest_pkey PRIMARY KEY (quest_id),
                                      CONSTRAINT quests_latest_quest_id_fkey FOREIGN KEY (quest_id) REFERENCES public.quests(id),
                                      CONSTRAINT quests_latest_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.quest_versions(id)
);
CREATE TABLE public.saved_themes (
                                     user_id uuid NOT NULL DEFAULT auth.uid(),
                                     theme_id uuid NOT NULL,
                                     CONSTRAINT saved_themes_pkey PRIMARY KEY (user_id, theme_id),
                                     CONSTRAINT saved_themes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                     CONSTRAINT saved_themes_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(id)
);
CREATE TABLE public.saved_videos (
                                     user_id uuid NOT NULL,
                                     video_id bigint NOT NULL,
                                     created_at timestamp with time zone NOT NULL DEFAULT now(),
                                     CONSTRAINT saved_videos_pkey PRIMARY KEY (user_id, video_id),
                                     CONSTRAINT saved_videos_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                     CONSTRAINT saved_videos_video_id_fkey FOREIGN KEY (video_id) REFERENCES public.videos(id)
);
CREATE TABLE public.tags (
                             id integer GENERATED ALWAYS AS IDENTITY NOT NULL,
                             name character varying NOT NULL UNIQUE,
                             CONSTRAINT tags_pkey PRIMARY KEY (id)
);
CREATE TABLE public.task_attempts (
                                      id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                      task_id bigint NOT NULL,
                                      version_id bigint NOT NULL,
                                      user_id uuid NOT NULL DEFAULT auth.uid(),
                                      answer_data jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(answer_data) = 'object'::text),
                                      evaluation jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(evaluation) = 'object'::text),
                                      is_correct boolean NOT NULL DEFAULT false,
                                      xp_delta double precision NOT NULL DEFAULT 0,
                                      created_at timestamp with time zone NOT NULL DEFAULT now(),
                                      CONSTRAINT task_attempts_pkey PRIMARY KEY (id),
                                      CONSTRAINT task_attempts_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id),
                                      CONSTRAINT task_attempts_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.task_versions(id)
);
CREATE TABLE public.task_solutions (
                                       solution_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                       task_id bigint NOT NULL,
                                       created_at timestamp with time zone NOT NULL DEFAULT now(),
                                       created_by uuid NOT NULL DEFAULT gen_random_uuid(),
                                       data jsonb NOT NULL,
                                       CONSTRAINT task_solutions_pkey PRIMARY KEY (solution_id),
                                       CONSTRAINT task_solutions_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id),
                                       CONSTRAINT task_solutions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.task_solves (
                                    user_id uuid NOT NULL DEFAULT auth.uid(),
                                    task_id bigint NOT NULL,
                                    solved_at timestamp with time zone NOT NULL,
                                    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                    CONSTRAINT task_solves_pkey PRIMARY KEY (id),
                                    CONSTRAINT task_solves_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id),
                                    CONSTRAINT task_solves_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.task_versions (
                                      id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                                      task_id bigint NOT NULL,
                                      version_no integer NOT NULL,
                                      status text NOT NULL DEFAULT 'draft'::text CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'archived'::text])),
                                      title text NOT NULL DEFAULT 'No Title Provided'::text,
                                      ui jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(ui) = 'object'::text),
                                      logic jsonb NOT NULL DEFAULT '{"pass": {"min_score": 0}, "rules": []}'::jsonb CHECK (jsonb_typeof(logic) = 'object'::text),
                                      created_by uuid NOT NULL DEFAULT auth.uid(),
                                      created_at timestamp with time zone NOT NULL DEFAULT now(),
                                      published_at timestamp with time zone,
                                      CONSTRAINT task_versions_pkey PRIMARY KEY (id),
                                      CONSTRAINT task_versions_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id)
);
CREATE TABLE public.tasks (
                              id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                              created_at timestamp with time zone NOT NULL DEFAULT now(),
                              created_by uuid DEFAULT auth.uid(),
                              title text DEFAULT 'No Title Provided'::text,
                              type text NOT NULL,
                              data jsonb NOT NULL,
                              subjects ARRAY NOT NULL DEFAULT '{General}'::text[],
                              xp_reward double precision NOT NULL DEFAULT '0.1'::double precision,
                              xp_punishment double precision NOT NULL DEFAULT '0'::double precision,
                              visibility text NOT NULL DEFAULT 'public'::text CHECK (visibility = ANY (ARRAY['private'::text, 'unlisted'::text, 'public'::text])),
                              current_version_id bigint,
                              CONSTRAINT tasks_pkey PRIMARY KEY (id),
                              CONSTRAINT tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
                              CONSTRAINT tasks_current_version_id_fkey FOREIGN KEY (current_version_id) REFERENCES public.task_versions(id)
);
CREATE TABLE public.theme_comments (
                                       id uuid NOT NULL DEFAULT uuid_generate_v4(),
                                       theme_id uuid,
                                       user_id uuid,
                                       comment_text text NOT NULL,
                                       created_at timestamp with time zone DEFAULT now(),
                                       CONSTRAINT theme_comments_pkey PRIMARY KEY (id),
                                       CONSTRAINT theme_comments_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(id),
                                       CONSTRAINT theme_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.theme_likes (
                                    id uuid NOT NULL DEFAULT uuid_generate_v4(),
                                    theme_id uuid,
                                    user_id uuid,
                                    created_at timestamp with time zone DEFAULT now(),
                                    CONSTRAINT theme_likes_pkey PRIMARY KEY (id),
                                    CONSTRAINT theme_likes_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(id),
                                    CONSTRAINT theme_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.themes (
                               id uuid NOT NULL DEFAULT uuid_generate_v4(),
                               created_at timestamp with time zone DEFAULT now(),
                               created_by uuid,
                               name text NOT NULL,
                               primary_color bigint NOT NULL,
                               is_public boolean DEFAULT false,
                               likes_count integer DEFAULT 0,
                               theme_data text,
                               original_theme_id uuid,
                               CONSTRAINT themes_pkey PRIMARY KEY (id),
                               CONSTRAINT themes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id),
                               CONSTRAINT themes_original_theme_id_fkey FOREIGN KEY (original_theme_id) REFERENCES public.themes(id)
);
CREATE TABLE public.user_interactions (
                                          user_id uuid NOT NULL DEFAULT gen_random_uuid(),
                                          video_id bigint,
                                          created_at timestamp with time zone NOT NULL DEFAULT now(),
                                          interaction_type text NOT NULL DEFAULT ''::text,
                                          additional_data jsonb,
                                          interaction_id uuid NOT NULL DEFAULT gen_random_uuid(),
                                          liked boolean NOT NULL DEFAULT false,
                                          watch_time double precision DEFAULT '0'::double precision,
                                          CONSTRAINT user_interactions_pkey PRIMARY KEY (interaction_id),
                                          CONSTRAINT user_interactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                          CONSTRAINT user_interactions_video_id_fkey FOREIGN KEY (video_id) REFERENCES public.videos(id)
);
CREATE TABLE public.video_reports (
                                      id bigint NOT NULL DEFAULT nextval('video_reports_id_seq'::regclass),
                                      user_id uuid NOT NULL,
                                      video_id bigint NOT NULL,
                                      reason text NOT NULL,
                                      status text NOT NULL DEFAULT 'pending'::text,
                                      created_at timestamp with time zone NOT NULL DEFAULT now(),
                                      CONSTRAINT video_reports_pkey PRIMARY KEY (id),
                                      CONSTRAINT video_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
                                      CONSTRAINT video_reports_video_id_fkey FOREIGN KEY (video_id) REFERENCES public.videos(id)
);
CREATE TABLE public.video_tags (
                                   video_id bigint NOT NULL,
                                   tag_id integer NOT NULL,
                                   CONSTRAINT video_tags_pkey PRIMARY KEY (video_id, tag_id),
                                   CONSTRAINT video_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id),
                                   CONSTRAINT video_tags_video_id_fkey FOREIGN KEY (video_id) REFERENCES public.videos(id)
);
CREATE TABLE public.videos (
                               id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
                               author_id uuid NOT NULL,
                               title character varying,
                               description character varying,
                               video_url text NOT NULL,
                               thumbnail_url text,
                               duration_ms smallint,
                               view_count smallint NOT NULL DEFAULT '0'::smallint,
                               like_count smallint NOT NULL DEFAULT '0'::smallint,
                               is_published boolean DEFAULT true,
                               created_at timestamp with time zone DEFAULT now(),
                               comment_count smallint NOT NULL,
                               fts tsvector DEFAULT to_tsvector('english'::regconfig, (((COALESCE(title, ''::character varying))::text || ' '::text) || (COALESCE(description, ''::character varying))::text)),
                               CONSTRAINT videos_pkey PRIMARY KEY (id),
                               CONSTRAINT videos_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id)
);