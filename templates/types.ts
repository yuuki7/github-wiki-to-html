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

export type RedirectProps = Omit<BaseProps, "language"> & {
  // A redirect stub's only text is the English word "Redirect", so the
  // component itself supplies the language; callers do not pass one.
  language?: string;
  targetSlug: string;
};
