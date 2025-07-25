module Users
  class SuggestProminent
    RETURNING = 20

    def self.call(user, attributes_to_select: [])
      new(user, attributes_to_select: attributes_to_select).suggest
    end

    def initialize(user, attributes_to_select: [])
      @user = user
      @attributes_to_select = attributes_to_select
    end

    def suggest
      User.joins(:profile).where(id: fetch_and_pluck_user_ids.uniq)
        .limit(RETURNING).select(attributes_to_select)
    end

    private

    attr_reader :user, :attributes_to_select

    def tags_to_consider
      user.decorate.cached_followed_tag_names
    end

    def fetch_and_pluck_user_ids
      lookback_setting = Settings::UserExperience.feed_lookback_days.to_i
      lookback = lookback_setting.positive? ? lookback_setting.days.ago : 2.weeks.ago
      filtered_articles = if tags_to_consider.any?
                            Article.published.from_subforem.cached_tagged_with_any(tags_to_consider).where("published_at > ?", lookback).where("score > ?", Settings::UserExperience.index_minimum_score * 2)
                          else
                            Article.published.from_subforem.featured.where("published_at > ?", lookback).where("score > ?", Settings::UserExperience.index_minimum_score * 2)
                          end
      user_ids = filtered_articles.order("score DESC").limit(RETURNING * 2).pluck(:user_id) - [user.id]
      if user_ids.size > (RETURNING / 5)
        user_ids.sample(RETURNING)
      else
        # This is a fallback in case we don't have enough users to return
        # Will generally not be called — but maybe for brand new forems
        User.order("score DESC").limit(RETURNING * 2).ids - [user.id]
      end
    end
  end
end
