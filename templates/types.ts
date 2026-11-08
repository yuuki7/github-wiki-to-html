export interface ArticleMetaProps {
  author: string;
  creationDate: string;
  modifiedDate?: string;
}

export type ArticleProps =
  | { title: string; isHome: true; meta?: undefined }
  | { title: string; isHome?: false; meta: ArticleMetaProps };

export type PageProps = ArticleProps & { className?: string; language?: string };
