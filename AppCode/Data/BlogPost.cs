namespace AppCode.Data
{
  public partial class BlogPost
  {
    // Add your own properties and methods here
    public string Summary => Content.Length > 100 ? Content.Substring(0, 100) + "..." : Content;
  }
}
