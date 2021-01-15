{% extends '_layout.swig' %}
{% import '_macro/sidebar.swig' as sidebar_template with context %}

{% block title %}{{ page.title }} | {{ title }}{% endblock %}

{% if not is_index and theme.facebook_sdk.enable and theme.facebook_sdk.like_button %}
  &nbsp; | &nbsp;
  <div class="fb-like" data-layout="button_count" data-share="true"></div>
{% endif %}

{% block class %}post posts-expand{% endblock %}

{% block content %}

  {{ partial('_macro/post.swig', {post: page}) }}

{% endblock %}

{% block sidebar %}
  {{ sidebar_template.render(true) }}
{% endblock %}
