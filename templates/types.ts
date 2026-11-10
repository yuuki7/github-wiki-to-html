export interface ArticleMetaProps {
  author: string;
  creationDate: string;
  modifiedDate?: string;
}

export interface BaseProps {
  title: string;
  language: string;
  className?: string;
}

export type ArticleProps = BaseProps & {
  isHome?: boolean;
  meta?: ArticleMetaProps;
};

export type HomeProps = BaseProps & {
  isHome?: true;
};

export type RedirectProps = BaseProps & {
  targetSlug: string;
};
